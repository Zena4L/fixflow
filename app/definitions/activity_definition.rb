class ActivityDefinition < ::ResourceDefinition
  field :actor_name, label: "By"
  field :summary, label: "Event"
  display :created_at, as: :relative_time, label: "When"

  default_sort :created_at, :asc
end
