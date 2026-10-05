#!/usr/bin/env python3
"""Monday-anchored Europe/Berlin week boundaries for Amplitude queries.

Amplitude weeks start Monday and the project timezone is Europe/Berlin. Deriving these
epochs by hand is where off-by-one-day boundaries come from, so derive them here instead.

Usage:  python3 week_bounds.py [n]     # default 4 complete weeks
"""
import sys
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Europe/Berlin")


def main(n: int) -> None:
    now = datetime.now(TZ)
    # Monday 00:00 of the week currently in progress. Everything before this is complete.
    this_monday = (now - timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    weeks = [this_monday - timedelta(weeks=i) for i in range(n, 0, -1)]

    print(f"now                {now:%Y-%m-%d %H:%M %a}")
    print(f"current week began {this_monday:%Y-%m-%d} (IN PROGRESS, do not quote)")
    print(f"last complete week {weeks[-1]:%Y-%m-%d} to "
          f"{weeks[-1] + timedelta(days=6):%Y-%m-%d}\n")

    print(f"{'week starts':<14}{'week ends':<14}{'start epoch':>13}")
    for w in weeks:
        print(f"{w:%Y-%m-%d}    {w + timedelta(days=6):%Y-%m-%d}    "
              f"{int(w.timestamp()):>13}")

    print(f"\nlast {n} complete weeks, paste into date_range:")
    print(f'  "start": {int(weeks[0].timestamp())},')
    print(f'  "end":   {int(this_monday.timestamp())},   '
          f'# exclusive: {this_monday:%Y-%m-%d} 00:00')
    print('  "timezone": "Europe/Berlin"')
    print("\nReminder: `end` does NOT truncate a week bucket in segmentation, and a")
    print("calendar-complete week is still immature for any metric with a conversion lag.")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 4)
