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
