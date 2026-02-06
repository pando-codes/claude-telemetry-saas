import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { HourlyHeatmap } from "@/components/charts/hourly-heatmap";
import { DailyActivityChart } from "@/components/charts/daily-activity-chart";
import type { HourlyHeatmapEntry, DailyActivity } from "@/types/analytics";

export default async function ActivityPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const [heatmapResult, dailyResult, stopReasonsResult] = await Promise.all([
    supabase.rpc("get_hourly_heatmap", { p_user_id: user.id }),
    supabase
      .from("daily_activity")
      .select("date, sessions, events, tool_uses")
      .eq("user_id", user.id)
      .order("date", { ascending: true })
      .limit(90),
    supabase.rpc("get_stop_reasons", { p_user_id: user.id }),
  ]);

  const heatmapData: HourlyHeatmapEntry[] = heatmapResult.data ?? [];
  const dailyActivity: DailyActivity[] = dailyResult.data ?? [];
  const stopReasons: { reason: string; count: number }[] =
    stopReasonsResult.data ?? [];

  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Activity</h1>
        <p className="text-sm text-muted-foreground">
          Patterns and trends in your Claude Code usage.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Activity Heatmap</CardTitle>
        </CardHeader>
        <CardContent>
          <HourlyHeatmap data={heatmapData} />
        </CardContent>
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Daily Activity</CardTitle>
          </CardHeader>
          <CardContent>
            <DailyActivityChart data={dailyActivity} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Stop Reasons</CardTitle>
          </CardHeader>
          <CardContent>
            {stopReasons.length === 0 ? (
              <p className="text-sm text-muted-foreground">No data available.</p>
            ) : (
              <div className="space-y-3">
                {stopReasons.map((item) => {
                  const total = stopReasons.reduce((sum, r) => sum + r.count, 0);
                  const pct = total > 0 ? (item.count / total) * 100 : 0;
                  return (
                    <div key={item.reason} className="space-y-1">
                      <div className="flex items-center justify-between text-sm">
                        <span className="font-medium">
                          {item.reason || "unknown"}
                        </span>
                        <span className="text-muted-foreground">
                          {item.count} ({pct.toFixed(0)}%)
                        </span>
                      </div>
                      <div className="h-2 w-full rounded-full bg-muted">
                        <div
                          className="h-2 rounded-full bg-chart-1"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
