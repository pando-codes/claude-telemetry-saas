import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import type { SessionSummary } from "@/types/analytics";

interface SessionsPageProps {
  searchParams: Promise<{ page?: string }>;
}

const PAGE_SIZE = 20;

function formatDuration(ms: number | null): string {
  if (ms === null) return "--";
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  return `${hours}h ${remainingMinutes}m`;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default async function SessionsPage({ searchParams }: SessionsPageProps) {
  const params = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const page = Math.max(1, parseInt(params.page ?? "1", 10));
  const offset = (page - 1) * PAGE_SIZE;

  const { data, count } = await supabase
    .from("sessions")
    .select("*", { count: "exact" })
    .eq("user_id", user.id)
    .order("started_at", { ascending: false })
    .range(offset, offset + PAGE_SIZE - 1);

  const sessions: SessionSummary[] = data ?? [];
  const totalPages = Math.ceil((count ?? 0) / PAGE_SIZE);

  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Sessions</h1>
        <p className="text-sm text-muted-foreground">
          Browse your Claude Code sessions.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Sessions</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Started</TableHead>
                <TableHead>Duration</TableHead>
                <TableHead className="text-right">Events</TableHead>
                <TableHead className="text-right">Tools</TableHead>
                <TableHead>Branch</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {sessions.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center text-muted-foreground">
                    No sessions found.
                  </TableCell>
                </TableRow>
              ) : (
                sessions.map((session) => (
                  <TableRow key={session.id}>
                    <TableCell>
                      <Link
                        href={`/sessions/${session.id}`}
                        className="text-primary underline-offset-4 hover:underline"
                      >
                        {formatDate(session.started_at)}
                      </Link>
                    </TableCell>
                    <TableCell>{formatDuration(session.duration_ms)}</TableCell>
                    <TableCell className="text-right">{session.event_count}</TableCell>
                    <TableCell className="text-right">{session.tool_count}</TableCell>
                    <TableCell>
                      {session.git_branch ? (
                        <Badge variant="secondary">{session.git_branch}</Badge>
                      ) : (
                        <span className="text-muted-foreground">--</span>
                      )}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>

          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-center gap-2">
              {page > 1 && (
                <Link
                  href={`/sessions?page=${page - 1}`}
                  className="text-sm text-primary underline-offset-4 hover:underline"
                >
                  Previous
                </Link>
              )}
              <span className="text-sm text-muted-foreground">
                Page {page} of {totalPages}
              </span>
              {page < totalPages && (
                <Link
                  href={`/sessions?page=${page + 1}`}
                  className="text-sm text-primary underline-offset-4 hover:underline"
                >
                  Next
                </Link>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
