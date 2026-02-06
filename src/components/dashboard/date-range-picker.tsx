"use client";

import { useState } from "react";
import { format, subDays } from "date-fns";
import { CalendarIcon } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import type { DateRange } from "@/types/analytics";

interface DateRangePickerProps {
  value?: DateRange;
  onRangeChange: (range: DateRange) => void;
}

function defaultRange(): DateRange {
  return {
    from: subDays(new Date(), 30),
    to: new Date(),
  };
}

export function DateRangePicker({ value, onRangeChange }: DateRangePickerProps) {
  const [open, setOpen] = useState(false);
  const range = value ?? defaultRange();

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          className={cn(
            "justify-start text-left font-normal",
            !value && "text-muted-foreground"
          )}
        >
          <CalendarIcon className="size-4" />
          {range.from ? (
            range.to ? (
              <>
                {format(range.from, "MMM d, yyyy")} -{" "}
                {format(range.to, "MMM d, yyyy")}
              </>
            ) : (
              format(range.from, "MMM d, yyyy")
            )
          ) : (
            <span>Pick a date range</span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="range"
          defaultMonth={range.from}
          selected={{ from: range.from, to: range.to }}
          onSelect={(selected) => {
            if (selected?.from && selected?.to) {
              onRangeChange({ from: selected.from, to: selected.to });
              setOpen(false);
            }
          }}
          numberOfMonths={2}
        />
      </PopoverContent>
    </Popover>
  );
}
