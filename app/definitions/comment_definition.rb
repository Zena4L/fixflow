class CommentDefinition < ::ResourceDefinition
  field :author_name, label: "Author"
  input :body, as: :text, label: "Comment"
  display :body, wrapper: {class: "col-span-full"}
  display :created_at, as: :relative_time

  default_sort :created_at, :asc
end
