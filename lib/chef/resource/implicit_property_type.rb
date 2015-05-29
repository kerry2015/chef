require 'chef/resource/property_type'

class Chef
  class Resource
    #
    # When the Resource class creates a property by itself, the user is using
    # their own methods to manage state.  We don't make any assumptions about
    # where the data is stored, in that case.
    #
    class ImplicitPropertyType < PropertyType
      def get_value(resource, name)
        resource.send(name)
      end
      def set_value(resource, name, value)
        resource.send(name, value)
      end
      def value_is_set?(resource, name)
        true
      end
    end
  end
end
