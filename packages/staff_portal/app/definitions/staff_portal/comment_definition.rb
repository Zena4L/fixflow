class StaffPortal::CommentDefinition < ::CommentDefinition
  include StaffPortal::ResourceDefinition

  input :internal, label: "Internal note", hint: "Internal notes are only visible to staff."
  display :internal, as: :boolean, true_label: "Internal", false_label: "Public"
end
