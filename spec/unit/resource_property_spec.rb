require 'support/shared/integration/integration_helper'

describe "Chef::Resource.property" do
  include IntegrationSupport

  class NewResourceNamer
    @i = 0
    def self.next
      "chef_resource_property_spec_#{@i += 1}"
    end
  end

  def self.new_resource_name
    NewResourceNamer.next
  end

  let(:resource_class) do
    new_resource_name = self.class.new_resource_name
    Class.new(Chef::Resource) do
      resource_name new_resource_name
    end
  end

  let(:resource) do
    resource_class.new("blah")
  end

  def self.english_join(values)
    return '<nothing>' if values.size == 0
    return values[0].inspect if values.size == 1
    "#{values[0..-2].map { |v| v.inspect }.join(", ")} and #{values[-1].inspect}"
  end

  def self.with_property(*properties, &block)
    tags_index = properties.find_index { |p| !p.is_a?(String)}
    if tags_index
      properties, tags = properties[0..tags_index-1], properties[tags_index..-1]
    else
      tags = []
    end
    properties = properties.map { |property| "property #{property}" }
    context "With properties #{english_join(properties)}", *tags do
      before do
        properties.each do |property_str|
          resource_class.class_eval(property_str, __FILE__, __LINE__)
        end
      end
      instance_eval(&block)
    end
  end

  # Basic properties
  with_property ":bare_property" do
    it "can be set" do
      expect(resource.bare_property 10).to eq 10
      expect(resource.bare_property).to eq 10
    end
    it "emits a deprecation warning and does a get, if set to nil" do
      expect(resource.bare_property 10).to eq 10
      expect { resource.bare_property nil }.to raise_error Chef::Exceptions::DeprecatedFeatureError
      Chef::Config[:treat_deprecation_warnings_as_errors] = false
      expect(resource.bare_property nil).to eq 10
      expect(resource.bare_property).to eq 10
    end
    it "can be updated" do
      expect(resource.bare_property 10).to eq 10
      expect(resource.bare_property 20).to eq 20
      expect(resource.bare_property).to eq 20
    end
    it "can be set with =" do
      expect(resource.bare_property 10).to eq 10
      expect(resource.bare_property).to eq 10
    end
    it "can be set to nil with =" do
      expect(resource.bare_property 10).to eq 10
      expect(resource.bare_property = nil).to be_nil
      expect(resource.bare_property).to be_nil
    end
    it "can be updated with =" do
      expect(resource.bare_property 10).to eq 10
      expect(resource.bare_property = 20).to eq 20
      expect(resource.bare_property).to eq 20
    end
  end

  # default
  # name_attribute
  # coerce
  # lazy
  # to hash, json
  # TODO "is" and types: coercion, defaults, name_attribute, identity, lazy values, and validation
end
