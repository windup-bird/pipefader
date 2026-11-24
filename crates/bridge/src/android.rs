//! The JNI hand-off Flutter cannot provide on its own.
//!
//! `cpal`'s oboe backend and `midir`'s Android backend both read `ndk_context` to get a `JavaVM`
//! and an Android `Context`. A normal `ndk-glue` app initializes that before `main`; a Flutter
//! embedding does not, so MainActivity loads the bridge and calls this once.

use std::ffi::c_void;
use std::sync::Once;

use jni::objects::JObject;
use jni::JNIEnv;

static INIT: Once = Once::new();

/// Called from `MainActivity.nativeInit(applicationContext)` after `System.loadLibrary("bridge")`.
/// The symbol embeds the applicationId/class and JNI's escaping (`_` becomes `_1`); it must change
/// with the package, or native init silently falls back to a panic later in cpal/midir.
#[no_mangle]
pub extern "system" fn Java_com_example_pipefader_1gui_MainActivity_nativeInit(
    env: JNIEnv,
    _this: JObject,
    context: JObject,
) {
    INIT.call_once(|| {
        let Ok(vm) = env.get_java_vm() else {
            return;
        };
        let Ok(global) = env.new_global_ref(context) else {
            return;
        };
        let vm = vm.get_java_vm_pointer() as *mut c_void;
        let context = global.as_obj().as_raw() as *mut c_void;
        // ndk-context keeps the raw pointer, so the global ref has to live for the process.
        std::mem::forget(global);
        unsafe {
            ndk_context::initialize_android_context(vm, context);
        }
    });
}
