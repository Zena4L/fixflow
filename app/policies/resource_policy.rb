# App-wide policy defaults. Deny by default: every resource policy must
# explicitly grant create?/read? (and everything derived from them).
class ResourcePolicy < Plutonium::Resource::Policy
  def create?
    false
  end

  def read?
    false
  end
end
