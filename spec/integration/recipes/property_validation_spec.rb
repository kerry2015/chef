require 'support/shared/integration/integration_helper'

describe "Chef::Resource::.property validation" do
  include IntegrationSupport

  # Bare types
  # is
  # - Class, Regex, Symbol, nil, PropertyType, RSpec::Matcher
  # equal_to
  # kind_of
  # regex
  # callbacks
  # respond_to
  # cannot_be
  # required
end
