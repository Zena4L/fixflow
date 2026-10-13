namespace :fixflow do
  desc "Create (or reset the password of) a staff admin: EMAIL=… NAME=… PASSWORD=… bin/rails fixflow:create_admin"
  task create_admin: :environment do
    email = ENV.fetch("EMAIL") { abort "EMAIL is required" }
    password = ENV.fetch("PASSWORD") { abort "PASSWORD is required" }
    abort "PASSWORD must be at least 12 characters" if password.length < 12

    admin = StaffMember.find_or_initialize_by(email:)
    admin.name = ENV.fetch("NAME", admin.name.presence || "Administrator")
    admin.role = :admin
    admin.active = true
    admin.status = :verified
    admin.password = password
    admin.save!

    puts "Staff admin #{admin.email} is ready. Sign in at /staff_members/login."
  end
end

namespace :fixflow do
  # Run by bin/docker-entrypoint at every boot, for hosts with no shell
  # (Vercel). Creates the first admin from ADMIN_EMAIL / ADMIN_PASSWORD only
  # while no admin exists, so it never resets an existing account.
  desc "Create the first staff admin from ADMIN_EMAIL/ADMIN_PASSWORD if there is no admin yet"
  task bootstrap_admin: :environment do
    email = ENV["ADMIN_EMAIL"].presence
    password = ENV["ADMIN_PASSWORD"].presence
    next unless email && password
    next if StaffMember.admin.exists?

    if password.length < 12
      warn "fixflow:bootstrap_admin skipped: ADMIN_PASSWORD must be at least 12 characters."
      next
    end

    StaffMember.create!(email:, name: ENV.fetch("ADMIN_NAME", "Administrator"), role: :admin,
      active: true, status: :verified, password:)
    puts "fixflow:bootstrap_admin created staff admin #{email.downcase}."
  end
end
