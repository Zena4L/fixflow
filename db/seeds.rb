# Demo data for local development. Idempotent: safe to run repeatedly.
# Never run against production — the demo password is public.
# `db:prepare` runs this file whenever it creates a database, including on a
# fresh production database at container boot, so skip without failing.
if Rails.env.production?
  puts "Skipping demo seeds in production (create staff with fixflow:create_admin)."
  return
end

DEMO_PASSWORD = "password123"

def staff(email, name, role)
  StaffMember.find_or_create_by!(email:) do |member|
    member.name = name
    member.role = role
    member.password = DEMO_PASSWORD
  end
end

def requester(email, name)
  User.find_or_create_by!(email:) do |user|
    user.name = name
    user.status = :verified
    user.password = DEMO_PASSWORD
  end
end

admin = staff("admin@fixflow.test", "Ada Admin", :admin)
agent = staff("agent@fixflow.test", "Alex Agent", :agent)
riley = requester("riley@fixflow.test", "Riley Requester")
sam = requester("sam@fixflow.test", "Sam Sender")

if ServiceRequest.none?
  # Requests are created as their requester and moved through the workflow as
  # staff, exactly as the portals would, so the activity log is realistic.
  Current.set(actor: riley) do
    ServiceRequest.create!(requester: riley, priority: :high, title: "Laptop will not connect to office Wi-Fi",
      description: "Since this morning my laptop sees the network but fails to connect. Other devices work.")
  end

  wifi = ServiceRequest.last
  wifi.transition_to!(:open, actor: agent)
  wifi.transition_to!(:in_progress, actor: agent)
  wifi.comments.create!(staff_member: agent, body: "Looks like an expired certificate. Pushing a new profile now.")
  wifi.comments.create!(staff_member: agent, internal: true, body: "Profile push job #4512 — check MDM logs if this recurs.")

  printer = Current.set(actor: sam) do
    ServiceRequest.create!(requester: sam, priority: :medium, title: "Third-floor printer jams on duplex",
      description: "Every double-sided job jams after the first page.")
  end
  printer.transition_to!(:open, actor: admin)
  printer.assign_to!(agent, actor: admin)
  printer.transition_to!(:in_progress, actor: agent)
  printer.transition_to!(:resolved, actor: agent, note: "Replaced the worn duplex roller.")

  Current.set(actor: riley) do
    ServiceRequest.create!(requester: riley, priority: :urgent, title: "Cannot access payroll system",
      description: "Payroll is due today and I get 'access denied' when I log in.")
    ServiceRequest.create!(requester: riley, priority: :low, title: "Request a second monitor",
      description: "A second monitor would help with spreadsheet work.")
  end
end

puts "Seeded #{StaffMember.count} staff, #{User.count} requesters, #{ServiceRequest.count} requests."
puts "Sign in with any demo account using the password #{DEMO_PASSWORD.inspect}:"
puts "  staff:      admin@fixflow.test (admin), agent@fixflow.test (agent)  -> /staff"
puts "  requesters: riley@fixflow.test, sam@fixflow.test                    -> /requester"
