import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { OverviewCards } from "@/components/dashboard/overview-cards";
import { DailyActivityChart } from "@/components/charts/daily-activity-chart";
import { ToolUsageChart } from "@/components/charts/tool-usage-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { OverviewStats, DailyActivity, ToolUsageStat } from "@/types/analytics";

export default async function OverviewPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const now = new Date();
  const thirtyDaysAgo = new Date(now);
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const p_from = thirtyDaysAgo.toISOString().substring(0, 10);
  const p_to = now.toISOString().substring(0, 10);

  const [statsResult, dailyResult, toolsResult] = await Promise.all([
    supabase.rpc("get_overview_stats", { p_user_id: user.id, p_from, p_to }),
    supabase
      .from("daily_aggregates")
      .select("date, sessions, events, tool_uses")
      .eq("user_id", user.id)
      .gte("date", p_from)
      .lte("date", p_to)
      .order("date", { ascending: true })
      .limit(30),
    supabase.rpc("get_top_tools", { p_user_id: user.id, p_from, p_to, p_limit: 10 }),
  ]);

  const stats: OverviewStats = statsResult.data ?? {
    total_sessions: 0,
    total_events: 0,
    total_tool_uses: 0,
    total_agent_calls: 0,
    active_days: 0,
    avg_session_duration_min: 0,
    avg_tools_per_session: 0,
  };

  const dailyActivity: DailyActivity[] = dailyResult.data ?? [];
  const topTools: ToolUsageStat[] = toolsResult.data ?? [];

  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Overview</h1>
        <p className="text-sm text-muted-foreground">
          Your Claude Code telemetry at a glance.
        </p>
      </div>

      <OverviewCards stats={stats} />

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
            <CardTitle>Top Tools</CardTitle>
          </CardHeader>
          <CardContent>
            <ToolUsageChart data={topTools} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
