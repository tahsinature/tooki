use serde::Deserialize;
use serde_json::{json, Map, Value};
use std::{collections::HashMap, time::Instant};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Raw {
    pub cpu_ticks: Vec<[u32; 4]>,
    pub processes: Vec<Process>,
    pub interfaces: Vec<Interface>,
    #[serde(flatten)]
    pub details: Map<String, Value>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Process {
    pub pid: u32,
    pub name: String,
    pub start: u64,
    pub cpu_time: u64,
    pub memory: u64,
}
#[derive(Deserialize)]
pub struct Interface {
    pub name: String,
    pub address: String,
    pub primary: bool,
    pub received: u64,
    pub sent: u64,
}
#[derive(Default)]
pub struct Sampler {
    previous: Option<(String, Instant, Raw)>,
}

pub fn rate(current: u64, previous: u64, seconds: f64) -> Option<f64> {
    (seconds > 0.0 && seconds <= 10.0)
        .then(|| {
            current
                .checked_sub(previous)
                .map(|delta| delta as f64 / seconds)
        })
        .flatten()
}
pub fn cpu_load(current: &[u32; 4], previous: &[u32; 4]) -> Option<f64> {
    let ticks: Vec<u64> = current
        .iter()
        .zip(previous)
        .map(|(c, p)| c.wrapping_sub(*p) as u64)
        .collect();
    let total: u64 = ticks.iter().sum();
    (total > 0).then(|| (total - ticks[2]) as f64 * 100.0 / total as f64)
}
impl Sampler {
    pub fn sample(&mut self, session: String, raw: Raw) -> Value {
        let now = Instant::now();
        let previous = self
            .previous
            .as_ref()
            .filter(|(id, time, _)| id == &session && time.elapsed().as_secs_f64() <= 10.0);
        let elapsed = previous.map(|(_, time, _)| now.duration_since(*time).as_secs_f64());
        let cores: Vec<Option<f64>> = raw
            .cpu_ticks
            .iter()
            .enumerate()
            .map(|(i, ticks)| {
                previous
                    .and_then(|(_, _, p)| p.cpu_ticks.get(i))
                    .and_then(|p| cpu_load(ticks, p))
            })
            .collect();
        let total = if cores.is_empty() || cores.iter().any(Option::is_none) {
            None
        } else {
            Some(cores.iter().flatten().sum::<f64>() / cores.len() as f64)
        };
        let old_processes: HashMap<_, _> = previous
            .into_iter()
            .flat_map(|(_, _, p)| &p.processes)
            .map(|p| ((p.pid, p.start), p.cpu_time))
            .collect();
        let mut processes: Vec<Value> = raw
            .processes
            .iter()
            .map(|p| {
                let cpu = old_processes
                    .get(&(p.pid, p.start))
                    .and_then(|old| rate(p.cpu_time, *old, elapsed?))
                    .map(|n| n / 1e7);
                json!({"pid":p.pid,"name":p.name,"memory":p.memory,"cpu":cpu})
            })
            .collect();
        processes.sort_by(|a, b| b["memory"].as_u64().cmp(&a["memory"].as_u64()));
        let top_memory: Vec<_> = processes.iter().take(3).cloned().collect();
        processes.sort_by(|a, b| {
            b["cpu"]
                .as_f64()
                .unwrap_or(0.0)
                .total_cmp(&a["cpu"].as_f64().unwrap_or(0.0))
        });
        let interfaces: Vec<Value> = raw.interfaces.iter().map(|i| {
            let old = previous.and_then(|(_,_,p)| p.interfaces.iter().find(|p| p.name == i.name && p.address == i.address));
            json!({"name":i.name,"address":i.address,"primary":i.primary,"received":i.received,"sent":i.sent,
                "download":old.and_then(|o| rate(i.received,o.received,elapsed?)),
                "upload":old.and_then(|o| rate(i.sent,o.sent,elapsed?))})
        }).collect();
        let mut output = raw.details.clone();
        let mut storage = output.get("storage").cloned().unwrap_or(json!({}));
        for (counter, key) in [("readBytes", "readRate"), ("writtenBytes", "writeRate")] {
            let value = previous.and_then(|(_, _, p)| {
                rate(
                    raw.details["storage"][counter].as_u64()?,
                    p.details["storage"][counter].as_u64()?,
                    elapsed?,
                )
            });
            storage[key] = json!(value);
        }
        output.insert("storage".into(), storage);
        output.insert("cpu".into(), json!({"total":total,"cores":cores}));
        output.insert("processCount".into(), json!(raw.processes.len()));
        output.insert(
            "topCpu".into(),
            json!(processes.into_iter().take(3).collect::<Vec<_>>()),
        );
        output.insert("topMemory".into(), json!(top_memory));
        output.insert("interfaces".into(), json!(interfaces));
        self.previous = Some((session, now, raw));
        Value::Object(output)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn counter_rates_reject_resets_and_suspended_intervals() {
        assert_eq!(rate(500, 100, 2.0), Some(200.0));
        assert_eq!(rate(100, 500, 2.0), None);
        assert_eq!(rate(500, 100, 0.0), None);
        assert_eq!(rate(500, 100, 12.0), None);
    }
    #[test]
    fn cpu_excludes_idle_and_handles_tick_wrap() {
        assert_eq!(cpu_load(&[20, 10, 70, 0], &[0; 4]), Some(30.0));
        assert_eq!(cpu_load(&[0; 4], &[0; 4]), None);
        assert_eq!(cpu_load(&[4, 0, 5, 0], &[u32::MAX, 0, 0, 0]), Some(50.0));
    }
}
