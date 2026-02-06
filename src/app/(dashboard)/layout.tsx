import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Sidebar } from "@/components/dashboard/sidebar";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const displayName =
    user.user_metadata?.display_name ??
    user.user_metadata?.full_name ??
    user.email ??
    "User";
  const avatarUrl = user.user_metadata?.avatar_url ?? null;

  return (
    <div className="flex min-h-screen">
      <Sidebar
        userName={displayName}
        avatarUrl={avatarUrl}
        userEmail={user.email ?? ""}
      />
      <main className="flex-1 ml-64 min-h-screen bg-background">
        {children}
      </main>
    </div>
  );
}
