package com.example.pipefader_gui

import android.Manifest
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.os.Environment
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var sessionChannel: MethodChannel? = null
    private var fileChannel: MethodChannel? = null
    private var pendingFile: MethodChannel.Result? = null
    private var pendingDirectory: MethodChannel.Result? = null
    private var volumeCallback: StorageManager.StorageVolumeCallback? = null
    private var mediaReceiver: BroadcastReceiver? = null
    private var usbPermissionReceiver: BroadcastReceiver? = null
    private val volumePaths = mutableMapOf<String, String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            System.loadLibrary("bridge")
            nativeInit(applicationContext)
        } catch (error: Throwable) {
            Log.e("Pipefader", "native initialization failed", error)
        }
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
        sessionChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sessionPaths" -> result.success(sessionPaths())
                "hasStoragePermission" -> result.success(hasStoragePermission())
                "requestStoragePermission" -> {
                    requestStoragePermission()
                    result.success(null)
                }
                "listVolumes" -> result.success(listVolumes())
                "restartApp" -> {
                    restartApp()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val fileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
        this.fileChannel = fileChannel
        fileChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickMapFile" -> pickMapFile(result)
                "pickDirectory" -> pickDirectory(result)
                else -> result.notImplemented()
            }
        }
        registerVolumeEvents()
        registerUsbPermissionEvents()
        requestMidiUsbPermissions()
    }

    override fun onDestroy() {
        volumeCallback?.let {
            getSystemService(StorageManager::class.java).unregisterStorageVolumeCallback(it)
        }
        mediaReceiver?.let { unregisterReceiver(it) }
        usbPermissionReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    /**
     * Android app processes have no HOME or XDG directories. The app's files directory is the
     * private, persistent home; the database lives there too so the system does not evict it.
     */
    @Suppress("DEPRECATION")
    private fun sessionPaths(): Map<String, Any> {
        val base = File(filesDir, "pipefader")
        return mapOf(
            "config" to File(base, "config.toml").absolutePath,
            "cache" to base.absolutePath,
            "mediaHome" to Environment.getExternalStorageDirectory().absolutePath,
            "log" to File(base, "logs").absolutePath,
            "seed" to true,
        )
    }

    /** Android 11+ has the all-files special access; Android 10 falls back to the legacy grant. */
    private fun hasStoragePermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager()
        }
        return checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent =
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName"),
                )
            try {
                startActivity(intent)
            } catch (_: ActivityNotFoundException) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ),
                STORAGE_REQUEST,
            )
        }
    }

    /**
     * The host owns removable-volume discovery. Android 11+ has StorageVolumeCallback; Android 10
     * listens to the media broadcasts. Both paths report the mount root to Dart, which forwards it
     * to the same Rust worker the desktop watcher feeds.
     */
    private fun registerVolumeEvents() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = getSystemService(StorageManager::class.java)
            val callback =
                object : StorageManager.StorageVolumeCallback() {
                    override fun onStateChanged(volume: StorageVolume) {
                        when (volume.state) {
                            Environment.MEDIA_MOUNTED -> emitMounted(volume)
                            Environment.MEDIA_UNMOUNTED,
                            Environment.MEDIA_REMOVED,
                            Environment.MEDIA_BAD_REMOVAL,
                            Environment.MEDIA_EJECTING -> emitUnmounted(volume)
                        }
                    }
                }
            manager.registerStorageVolumeCallback(mainExecutor, callback)
            volumeCallback = callback
        } else {
            val receiver =
                object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        val path = intent.data?.path ?: return
                        if (intent.action == Intent.ACTION_MEDIA_MOUNTED) {
                            volumePaths[path] = path
                            sessionChannel?.invokeMethod("volumeMounted", path)
                        } else {
                            volumePaths.remove(path)
                            sessionChannel?.invokeMethod("volumeUnmounted", path)
                        }
                    }
                }
            val filter =
                IntentFilter().apply {
                    addAction(Intent.ACTION_MEDIA_MOUNTED)
                    addAction(Intent.ACTION_MEDIA_UNMOUNTED)
                    addAction(Intent.ACTION_MEDIA_REMOVED)
                    addAction(Intent.ACTION_MEDIA_BAD_REMOVAL)
                    addDataScheme("file")
                }
            registerReceiver(receiver, filter)
            mediaReceiver = receiver
        }
    }

    /**
     * midir opens MIDI devices but never asks for the USB grant, so no system dialog appears and
     * `openDevice` returns null. The grant is per UsbDevice; ask for every attached USB audio
     * device with a MIDI-streaming interface before the menu probes ports.
     */
    private fun registerUsbPermissionEvents() {
        val receiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
                        requestMidiUsbPermissions()
                    }
                }
            }
        val filter =
            IntentFilter().apply {
                addAction(ACTION_USB_PERMISSION)
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        usbPermissionReceiver = receiver
    }

    private fun requestMidiUsbPermissions() {
        val usb = getSystemService(UsbManager::class.java)
        val flags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
        for (device in usb.deviceList.values) {
            if (!hasMidiStreamingInterface(device) || usb.hasPermission(device)) continue
            val intent = Intent(ACTION_USB_PERMISSION).setPackage(packageName)
            val pending = PendingIntent.getBroadcast(this, device.deviceId, intent, flags)
            usb.requestPermission(device, pending)
        }
    }

    private fun hasMidiStreamingInterface(device: UsbDevice): Boolean {
        for (index in 0 until device.interfaceCount) {
            val intf = device.getInterface(index)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_AUDIO &&
                intf.interfaceSubclass == MIDI_STREAMING_SUBCLASS
            ) {
                return true
            }
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_MAP) {
            val result = pendingFile ?: return
            pendingFile = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                result.success(null)
                return
            }
            try {
                val bytes =
                    contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes == null) {
                    result.error("read-failed", "the document could not be opened", null)
                    return
                }
                val name = displayName(uri) ?: "map.toml"
                result.success(mapOf("name" to name, "bytes" to bytes))
            } catch (error: Exception) {
                result.error("read-failed", error.message, null)
            }
            return
        }
        if (requestCode == REQUEST_PICK_DIRECTORY) {
            val result = pendingDirectory ?: return
            pendingDirectory = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                result.success(null)
                return
            }
            val path = treeToPath(uri)
            if (path == null) {
                result.error(
                    "unsupported-provider",
                    "choose a folder on local or removable storage",
                    null,
                )
            } else {
                result.success(path)
            }
        }
    }

    /**
     * A controller map is read as bytes: SAF has no path the Rust side could open, and both
     * platforms use the same import path afterward.
     */
    private fun pickMapFile(result: MethodChannel.Result) {
        if (pendingFile != null) {
            result.error("busy", "a file dialog is already open", null)
            return
        }
        pendingFile = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            startActivityForResult(intent, REQUEST_PICK_MAP)
        } catch (error: Exception) {
            pendingFile = null
            result.error("unavailable", error.message, null)
        }
    }

    /** The library scanner needs a real path, so the SAF tree is converted for external storage. */
    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectory != null) {
            result.error("busy", "a folder dialog is already open", null)
            return
        }
        pendingDirectory = result
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQUEST_PICK_DIRECTORY)
        } catch (error: Exception) {
            pendingDirectory = null
            result.error("unavailable", error.message, null)
        }
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index < 0) null else cursor.getString(index)
            }
            ?: uri.lastPathSegment

    /** `primary:Music` -> `/storage/emulated/0/Music`; `ABCD-1234:Music` -> `/storage/ABCD-1234/Music`. */
    private fun treeToPath(uri: Uri): String? {
        if (!DocumentsContract.isTreeUri(uri)) return null
        if (uri.authority != "com.android.externalstorage.documents") return null
        val document = DocumentsContract.getTreeDocumentId(uri)
        val parts = document.split(":", limit = 2)
        val volume = parts[0]
        val relative = if (parts.size > 1) parts[1] else ""
        val root =
            if (volume == "primary") {
                Environment.getExternalStorageDirectory().absolutePath
            } else {
                "/storage/$volume"
            }
        return if (relative.isEmpty()) root else "$root/$relative"
    }

    /** Kills the process after queueing a fresh activity; the Rust session boots again from disk. */
    private fun restartApp() {
        val intent =
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
        val pending =
            PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT,
            )
        try {
            pending.send()
        } catch (_: PendingIntent.CanceledException) {
            // The launcher already has the task; the process exit below is still enough.
        }
        finishAffinity()
        Runtime.getRuntime().exit(0)
    }

    /**
     * Volumes already attached when the app starts. The Dart side asks for this after the engine
     * exists; sending them from configureFlutterEngine would race the Dart handler registration.
     */
    private fun listVolumes(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        return getSystemService(StorageManager::class.java).storageVolumes
            .filter { !it.isPrimary }
            .mapNotNull { volume ->
                val path = volume.directory?.absolutePath ?: return@mapNotNull null
                volumePaths[volume.uuid ?: path] = path
                path
            }
    }

    private fun emitMounted(volume: StorageVolume) {
        if (volume.isPrimary) return
        val path = volume.directory?.absolutePath ?: return
        val key = volume.uuid ?: path
        if (volumePaths.containsKey(key)) return
        volumePaths[key] = path
        sessionChannel?.invokeMethod("volumeMounted", path)
    }

    private fun emitUnmounted(volume: StorageVolume) {
        if (volume.isPrimary) return
        val key = volume.uuid ?: volume.directory?.absolutePath ?: return
        val path = volumePaths.remove(key) ?: volume.directory?.absolutePath ?: return
        sessionChannel?.invokeMethod("volumeUnmounted", path)
    }

    /** Implemented in crates/bridge/src/android.rs; makes ndk-context available to cpal/midir. */
    private external fun nativeInit(context: Context)

    private companion object {
        const val SESSION_CHANNEL = "pipefader/session"
        const val FILE_CHANNEL = "pipefader/file"
        const val REQUEST_PICK_MAP = 42
        const val REQUEST_PICK_DIRECTORY = 43
        const val ACTION_USB_PERMISSION = "com.example.pipefader_gui.USB_PERMISSION"
        const val MIDI_STREAMING_SUBCLASS = 3
        const val STORAGE_REQUEST = 41
    }
}
