//! Headless smoke test for the bridge session: boots the engine, waits for a
//! state tick and prints the deck snapshot. Not part of the Flutter app.
fn main() {
    bridge::api::start(None).expect("start");
    std::thread::sleep(std::time::Duration::from_millis(1500));
    for deck in 0..2 {
        match bridge::api::deck_meta(deck) {
            Ok(meta) => println!("deck{deck} meta: {:?}", meta.map(|m| m.title)),
            Err(err) => println!("deck{deck} meta error: {err}"),
        }
    }
    println!("logs: {:?}", bridge::api::logs().map(|logs| logs.len()));
    bridge::api::shutdown().expect("shutdown");
    println!("stopped");
}
