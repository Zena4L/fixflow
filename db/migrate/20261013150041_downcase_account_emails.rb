# StaffMember and User now normalize email to lowercase, matching Rodauth's
# case_insensitive_login (which downcases the submitted login). Existing
# mixed-case rows could never sign in and would stop matching find_by(email:),
# so bring them in line.
class DowncaseAccountEmails < ActiveRecord::Migration[8.1]
  TABLES = %w[users staff_members].freeze

  def up
    TABLES.each do |table|
      # Two open accounts differing only by case would collide on the unique
      # index once lowercased. Stop and let a person decide which one to keep.
      clashes = select_values(<<~SQL)
        SELECT LOWER(TRIM(email)) FROM #{table}
        WHERE status IN (1, 2)
        GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1
      SQL
      if clashes.any?
        raise ActiveRecord::IrreversibleMigration,
          "#{table} has accounts whose emails differ only by case: #{clashes.join(", ")}. " \
          "Close or rename the duplicates, then rerun this migration."
      end

      execute "UPDATE #{table} SET email = LOWER(TRIM(email)) WHERE email <> LOWER(TRIM(email))"
    end
  end

  # The original casing is not kept and nothing depends on it.
  def down
  end
end
