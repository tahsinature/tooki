mod catalog;
#[cfg(any(target_os = "linux", test))]
#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
mod linux_catalog;
mod model;
mod platform;
pub use model::*;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    mpsc, Arc,
};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

pub fn capabilities() -> Capabilities {
    platform::capabilities()
}
pub fn lookup(combo: Combo, launcher: &str) -> Check {
    let matches = catalog::matches(&combo, launcher);
    Check { combo, outcome: "lookup".into(), detail: "Known assignments only. No delivery test was performed; an empty result does not mean this shortcut is available.".into(), app: None, matches }
}

/// Owns one native listener. Dropping it always requests shutdown and joins its worker.
pub struct Session {
    stop: Arc<AtomicBool>,
    worker: Option<JoinHandle<()>>,
}
impl Session {
    pub fn start(mode: Mode, launcher: String) -> Result<(Self, mpsc::Receiver<Message>), String> {
        let capabilities = capabilities();
        if !capabilities.can_observe || (mode == Mode::Block && !capabilities.can_block) {
            return Err(capabilities.explanation);
        }
        let stop = Arc::new(AtomicBool::new(false));
        let worker_stop = stop.clone();
        let (tx, rx) = mpsc::channel();
        let (ready_tx, ready_rx) = mpsc::sync_channel(1);
        let worker = std::thread::spawn(move || {
            let started = Instant::now();
            let mut report = |mut check: Check| {
                check
                    .matches
                    .extend(catalog::matches(&check.combo, &launcher));
                let _ = tx.send(Message::Check(check));
            };
            let running = || {
                !worker_stop.load(Ordering::Acquire) && started.elapsed() < Duration::from_secs(300)
            };
            let result = platform::run(mode, &running, &mut report, ready_tx);
            worker_stop.store(true, Ordering::Release);
            let reason = result.err().or_else(|| {
                (started.elapsed() >= Duration::from_secs(300))
                    .then(|| "Listening stopped after five minutes.".into())
            });
            let _ = tx.send(Message::Stopped(reason));
        });
        let session = Self {
            stop,
            worker: Some(worker),
        };
        match ready_rx.recv_timeout(Duration::from_secs(5)) {
            Ok(Ok(())) => Ok((session, rx)),
            Ok(Err(e)) => Err(e),
            Err(_) => Err("The native keyboard listener did not start.".into()),
        }
    }
    pub fn request_stop(&self) {
        self.stop.store(true, Ordering::Release);
    }
}
impl Drop for Session {
    fn drop(&mut self) {
        self.request_stop();
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}
