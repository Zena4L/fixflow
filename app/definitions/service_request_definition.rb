class ServiceRequestDefinition < ::ResourceDefinition
  STATUS_COLORS = {submitted: :info, open: :primary, in_progress: :warning, resolved: :success, closed: :neutral}.freeze
  PRIORITY_COLORS = {low: :neutral, medium: :info, high: :warning, urgent: :danger}.freeze

  field :reference, label: "Ref"
  input :title, placeholder: "Short summary, e.g. \"Laptop will not connect to Wi-Fi\""
  input :description, as: :text, hint: "What happened, where, and how it affects your work."
  input :priority, hint: "Urgent means work is blocked for you or others."

  display :status, as: :badge, colors: STATUS_COLORS
  display :priority, as: :badge, colors: PRIORITY_COLORS
  display :description, wrapper: {class: "col-span-full"}
  display :resolution_note, wrapper: {class: "col-span-full"}
  display :updated_at, as: :relative_time
  display :created_at, as: :relative_time

  # Matches a reference ("FF-00042", "42") or words in the title/description.
  search do |scope, query|
    term = query.to_s.strip
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    # Arel#matches is case-insensitive on both SQLite (LIKE) and Postgres (ILIKE).
    table = ServiceRequest.arel_table
    matches = scope.where(table[:title].matches(like).or(table[:description].matches(like)))
    id = term[/\A(?:#{ServiceRequest::REFERENCE_PREFIX})?0*(\d+)\z/io, 1]
    id ? matches.or(scope.where(id: id.to_i)) : matches
  end

  scope :active

  sorts :title, :priority, :status, :created_at, :updated_at
  default_sort :updated_at, :desc
end
