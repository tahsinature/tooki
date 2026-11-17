use serde::{Deserialize, Serialize};
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}
#[derive(Clone, Copy, Debug)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}
#[derive(Clone, Copy, Default, Debug, PartialEq, Serialize)]
pub struct Axes {
    pub x: bool,
    pub y: bool,
}

pub fn target(monitor: Rect, work: Rect, width: f64, height: f64) -> Point {
    clamp(
        Point {
            x: monitor.x + (monitor.width - width) / 2.0,
            y: monitor.y + monitor.height * 0.16,
        },
        work,
        width,
        height,
    )
}
pub fn clamp(point: Point, work: Rect, width: f64, height: f64) -> Point {
    Point {
        x: point
            .x
            .clamp(work.x, (work.x + work.width - width).max(work.x)),
        y: point
            .y
            .clamp(work.y, (work.y + work.height - height).max(work.y)),
    }
}
pub fn snap(point: Point, target: Point, scale: f64) -> (Point, Axes) {
    let axes = Axes {
        x: (point.x - target.x).abs() < 12.0 * scale,
        y: (point.y - target.y).abs() < 12.0 * scale,
    };
    (
        Point {
            x: if axes.x { target.x } else { point.x },
            y: if axes.y { target.y } else { point.y },
        },
        axes,
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn independent_axes_and_strict_threshold() {
        let t = Point { x: 100.0, y: 150.0 };
        let (p, a) = snap(Point { x: 111.9, y: 162.0 }, t, 1.0);
        assert_eq!(p, Point { x: 100.0, y: 162.0 });
        assert_eq!(a, Axes { x: true, y: false });
    }
    #[test]
    fn retina_threshold_uses_logical_pixels() {
        let (_, a) = snap(Point { x: 23.0, y: 24.0 }, Point { x: 0.0, y: 0.0 }, 2.0);
        assert_eq!(a, Axes { x: true, y: false });
    }
    #[test]
    fn target_on_negative_secondary_display() {
        let r = Rect {
            x: -2560.0,
            y: -300.0,
            width: 2560.0,
            height: 1440.0,
        };
        assert_eq!(
            target(r, r, 760.0, 520.0),
            Point {
                x: -1660.0,
                y: -69.6
            }
        );
    }
    #[test]
    fn compact_target_reserves_expanded_height_and_avoids_dock() {
        let m = Rect {
            x: 0.0,
            y: 0.0,
            width: 1440.0,
            height: 900.0,
        };
        let w = Rect {
            x: 0.0,
            y: 30.0,
            width: 1440.0,
            height: 600.0,
        };
        assert_eq!(target(m, w, 760.0, 520.0).y, 110.0);
    }
    #[test]
    fn oversized_windows_and_removed_displays_are_clamped() {
        let w = Rect {
            x: 0.0,
            y: 24.0,
            width: 640.0,
            height: 480.0,
        };
        assert_eq!(
            clamp(
                Point {
                    x: -3000.0,
                    y: 2000.0
                },
                w,
                760.0,
                520.0
            ),
            Point { x: 0.0, y: 24.0 }
        );
    }
}
