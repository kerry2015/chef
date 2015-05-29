require 'chef/exceptions'
require 'chef/delayed_evaluator'

class Chef
  class Resource
    #
    # Type and validation information for a property on a resource.
    #
    # A property named "x" manipulates the "@x" instance variable on a
    # resource.  The *presence* of the variable (`instance_variable_defined?(@x)`)
    # tells whether the variable is defined; it may have any actual value,
    # constrained only by validation.
    #
    # Properties may have validation, defaults, and coercion, and have fully
    # support for lazy values.
    #
    # @see Chef::Resource.property
    # @see Chef::DelayedEvaluator
    #
    class PropertyType
      #
      # Create a new property type.
      #
      # @raise ArgumentError If `:callbacks` is not a Hash.
      #
      def initialize(
        is: NULL_ARG,
        equal_to: NULL_ARG,
        regex: NULL_ARG,
        kind_of: NULL_ARG,
        respond_to: NULL_ARG,
        cannot_be: NULL_ARG,
        callbacks: NULL_ARG,

        coerce: NULL_ARG,
        required: NULL_ARG,
        name_property: NULL_ARG,
        default: NULL_ARG,
        desired_state: NULL_ARG,
        identity: NULL_ARG
      )
        # Validation args
        @is         = [ is ].flatten(1) unless is == NULL_ARG
        @equal_to   = [ equal_to ].flatten(1) unless equal_to == NULL_ARG
        @regex      = [ regex ].flatten(1) unless regex == NULL_ARG
        @kind_of    = [ kind_of ].flatten(1) unless kind_of == NULL_ARG
        @respond_to = [ respond_to ].flatten(1).map { |v| v.to_sym } unless respond_to == NULL_ARG
        @cannot_be  = [ cannot_be ].flatten(1).map { |v| v.to_sym } unless cannot_be == NULL_ARG
        @callbacks  = callbacks unless callbacks == NULL_ARG

        # Other properties
        @coerce         = coerce unless coerce == NULL_ARG
        @required       = required unless required == NULL_ARG
        @name_property  = name_property unless name_property == NULL_ARG
        @default        = default unless default == NULL_ARG
        @desired_state  = desired_state unless desired_state == NULL_ARG
        @identity       = identity unless identity == NULL_ARG

        raise ArgumentError, "Callback list must be a hash, is #{callbacks.inspect}!" if callbacks != NULL_ARG && !callbacks.is_a?(Hash)
      end

      #
      # List of valid things values can be.
      #
      # Uses Ruby's `===` to evaluate (is === value).  At least one must match
      # for the value to be valid.
      #
      # If a proc is passed, it is instance_eval'd in the resource, passed the
      # value, and must return a truthy or falsey value.
      #
      # @example Class
      #   ```ruby
      #   property :x, String
      #   x 'valid' #=> valid
      #   x 1       #=> invalid
      #   x nil     #=> invalid
      #
      # @example Value
      #   ```ruby
      #   property :x, [ :a, :b, :c, nil ]
      #   x :a  #=> valid
      #   x nil #=> valid
      #   ```
      #
      # @example Regex
      #   ```ruby
      #   property :x, /bar/
      #   x 'foobar' #=> valid
      #   x 'foo'    #=> invalid
      #   x nil      #=> invalid
      #   ```
      #
      # @example Proc
      #   ```ruby
      #   property :x, proc { |x| x > y }
      #   property :y, default: 2
      #   x 3 #=> valid
      #   x 1 #=> invalid
      #   ```
      #
      # @example PropertyType
      #   ```ruby
      #   type = PropertyType.new(is: String)
      #   property :x, type
      #   x 'foo' #=> valid
      #   x 1     #=> invalid
      #   x nil   #=> invalid
      #   ```
      #
      # @example RSpec Matcher
      #   ```ruby
      #   include RSpec::Matchers
      #   property :x, a_string_matching /bar/
      #   x 'foobar' #=> valid
      #   x 'foo'    #=> invalid
      #   x nil      #=> invalid
      #   ```
      #
      # @return [Array,nil] List of things this is, or nil if "is" is unspecified.
      #
      attr_reader :is

      #
      # List of things values must be equal to.
      #
      # Uses Ruby's `==` to evaluate (equal_to == value).  At least one must
      # match for the value to be valid.
      #
      # @return [Array,nil] List of things values must be equal to, or nil if
      #   equal_to is unspecified.
      #
      attr_reader :equal_to

      #
      # List of regexes values must match.
      #
      # Uses regex.match() to evaluate. At least one must match for the value to
      # be valid.
      #
      # @return [Array<Regex>,nil] List of regexes values must match, or nil if
      #   regex is unspecified.
      #
      attr_reader :regex

      #
      # List of things values must be equal to.
      #
      # Uses value.kind_of?(kind_of) to evaluate. At least one must match for
      # the value to be valid.
      #
      # @return [Array<Class>,nil] List of classes values must be equal to, or nil if
      #   kind_of is unspecified.
      #
      attr_reader :kind_of

      #
      # List of method names values must respond to.
      #
      # Uses value.respond_to?(respond_to) to evaluate. At least one must match
      # for the value to be valid.
      #
      # @return [Array<Symbol>,nil] List of classes values must be equal to, or
      #   `nil` if respond_to is unspecified.
      #
      attr_reader :respond_to

      #
      # List of things that must not be true about the value.
      #
      # Calls `value.<thing>?` All responses must be false. Values which do not
      # respond to <thing>? are considered valid (because if a value doesn't
      # respond to `:readable?`, then it probably isn't readable.)
      #
      # @return [Array<Symbol>,nil] List of classes values must be equal to, or
      #   `nil` if cannot_be is unspecified.
      #
      # @example
      #   ```ruby
      #   property :x, cannot_be: [ :nil, :empty ]
      #   x [ 1, 2 ] #=> valid
      #   x 1        #=> valid
      #   x []       #=> invalid
      #   x nil      #=> invalid
      #   ```
      #
      attr_reader :cannot_be

      #
      # List of procs we pass the value to.
      #
      # All procs must return true for the value to be valid. If any procs do
      # not return true, the key will be used for the message: `"Property x's
      # value :y <message>"`.
      #
      # @return [Hash<String,Proc>,nil] Hash of procs which must match, with
      #   their messages as the key. `nil` if callbacks is unspecified.
      #
      attr_reader :callbacks

      #
      # Whether this is required or not.
      #
      # @return [Boolean]
      #
      # @deprecated use default: lazy { name } instead.
      def required?
        @required
      end

      #
      # Whether this is part of the resource's natural identity or not.
      #
      # @return [Boolean]
      #
      # @deprecated use default: lazy { name } instead.
      def identity?
        @identity
      end

      #
      # Whether this is part of desired state or not.
      #
      # @return [Boolean]
      #
      # @deprecated use default: lazy { name } instead.
      def desired_state?
        defined?(@desired_state) ? @desired_state : true
      end

      #
      # Whether this is name_property or not.
      #
      # @return [Boolean]
      #
      # @deprecated use default: lazy { name } instead.
      def name_property?
        @name_property
      end

      #
      # Whether this has a default value or not.
      #
      # @return [Boolean]
      #
      def default?
        !!@default
      end

      #
      # Get the property value from the resource, handling lazy values,
      # defaults, and validation.
      #
      # - If the property's value is lazy, the lazy value is evaluated, coerced
      #   and validated, and the result stored in the property (it will not be
      #   evaluated twice).
      # - If the property has no value, but has a default, the default value
      #   will be returned. If the default value is lazy, it will be evaluated,
      #   coerced and validated, and the result stored in the property.
      # - If the property has no value, but is name_property, `resource.name`
      #   is retrieved, coerced, validated and stored in the property.
      # - Otherwise, `nil` is returned.
      #
      # @param resource [Chef::Resource] The resource to get the property from.
      # @param name [Symbol] The name of the property to set.
      #
      # @return The value of the property.
      #
      # @raise Chef::Exceptions::ValidationFailed If the value is invalid for
      #   this property.
      #
      def get(resource, name)
        # Grab the value
        if value_is_set?(resource, name)
          value = get_value(resource, name)

        # Use the default if it is there.
        elsif default?
          value = default
          set(resource, name, value)

        # Last ditch: if name_property is set, get that
        elsif name_property? && name != :name
          value = resource.name
          set(resource, name, value)
        end

        # If the value is lazy, pop it open and store it
        if value.is_a?(DelayedEvaluator)
          value = resource.instance_eval(&value)
          set(resource, name, value)
        end

        value
      end

      #
      # Get the default value for this property.
      #
      # - If the property has no value, but has a default, the default value
      #   will be returned. If the default value is lazy, it will be evaluated,
      #   coerced and validated.
      # - If the property has no value, but is name_property, `resource.name`
      #   is returned.
      # - Otherwise, `nil` is returned.
      #
      # This differs from `get` in that it will *not* store the default value in
      # the given resource.
      #
      # If resource and name are not passed, the default is returned without
      # evaluation, coercion or validation, and name_property is not honored.
      #
      # @param resource [Chef::Resource] The resource to get the default against.
      # @param name [Symbol] The name of the property to get the default of.
      #
      # @return The default value for the property.
      #
      # @raise Chef::Exceptions::ValidationFailed If the value is invalid for
      #   this property.
      #
      def default(resource=nil, name=nil)
        return @default if !resource && !name

        if defined?(@default)
          coerce(resource, name, @default)
        elsif name_property? && name != :name
          resource.name
        else
          nil
        end
      end

      #
      # Set the value of this property in the given resource.
      #
      # Non-lazy values are coerced and validated before being set. Coercion
      # and validation of lazy values is delayed until they are first retrieved.
      #
      # @param resource [Chef::Resource] The resource to set this property in.
      # @param name [Symbol] The name of the property to set.
      # @param value The value to set.
      #
      # @return The value that was set, after coercion (if lazy, still returns
      #   the lazy value)
      #
      # @raise Chef::Exceptions::ValidationFailed If the value is invalid for
      #   this property.
      #
      def set(resource, name, value)
        value = coerce(resource, name, value)
        set_value(resource, name, value)
      end

      #
      # Find out whether this property has been set.
      #
      # This will be true if:
      # - The user explicitly set the value
      # - The property is name_property and name has been set
      # - The property has a default, and the value was retrieved.
      #
      # From this point of view, it is worth looking at this as "what does the
      # user think this value should be." In order words, if the user grabbed
      # the value, even if it was a default, they probably based calculations on
      # it. If they based calculations on it and the value changes, the rest of
      # the world gets inconsistent.
      #
      # @param resource [Chef::Resource] The resource to get the property from.
      # @param name [Symbol] The name of the property to get.
      #
      # @return [Boolean]
      #
      def is_set?(resource, name)
        value_is_set?(resource, name) ||
        (name_property? && value_is_set?(resource, :name))
      end

      #
      # Coerce an input value into canonical form for the property, validating
      # it in the process.
      #
      # After coercion, the value is suitable for storage in the resource.
      #
      # Does not coerce or validate lazy values.
      #
      # @param resource [Chef::Resource] The resource we're coercing against
      #   (to provide context for the coerce).
      # @param name [Symbol] The name of the property we're coercing (to provide
      #   context for the coerce).
      # @param value The value to coerce.
      #
      # @return The coerced value.
      #
      # @raise Chef::Exceptions::ValidationFailed If the value is invalid for
      #   this property.
      #
      def coerce(resource, name, value)
        if !value.is_a?(DelayedEvaluator)
          value = resource.instance_exec(value, &@coerce) if @coerce
          errors = validate(resource, name, value)
          raise Chef::Exceptions::ValidationFailed, errors.map { |e| "Property #{name}'s #{e}" }.join("\n") if errors
        end
        value
      end

      #
      # Validate a value.
      #
      # Honors #is, #equal_to, #regex, #kind_of, #respond_to, #cannot_be, and
      # #callbacks.
      #
      # @param resource [Chef::Resource] The resource we're validating against
      #   (to provide context for the validate).
      # @param name [Symbol] The name of the property we're validating (to provide
      #   context for the validate).
      # @param value The value to validate.
      #
      # @return [Array<String>,nil] A list of errors, or nil if there was no error.
      #
      def validate(resource, name, value)
        errors = []

        # "is": capture the first type match so we can use it as the supertype
        #       for this value.
        error_unless_any_match(errors, value, is, "is not") do |v|
          case v
          when Proc
            resource.instance_eval(value, &v)
          when PropertyType
            got_errors = v.validate(resource, name, value)
            errors += got_errors if got_errors
            true
          else
            v === value
          end
        end

        # equal_to
        error_unless_any_match(errors, value, equal_to, "does not equal") do |v|
          v == value
        end

        # regex
        error_unless_any_match(errors, value, regex, "does not match") do |v|
          v.match(value)
        end

        # kind_of
        error_unless_any_match(errors, value, kind_of, "is not of type") do |v|
          value.kind_of?(v)
        end

        # respond_to
        error_unless_all_match(errors, value, respond_to, "does not respond to") do |v|
          value.respond_to?(v)
        end

        # cannot_be
        error_unless_all_match(errors, value, cannot_be,  "is") do |v|
          value.respond_to?("#{v}?") && value.send("#{v}?")
        end

        # callbacks
        error_unless_callbacks_match(value, errors, callbacks)

        errors.empty? ? nil : errors
      end

      #
      # Find out whether this type accepts nil explicitly.
      #
      # A type accepts nil explicitly if it validates as nil, *and* is not simply
      # an empty type.
      #
      # These examples accept nil explicitly:
      # ```ruby
      # property :a, [ String, nil ]
      # property :a, is: [ String, nil ]
      # property :a, equal_to: [ 1, 2, 3, nil ]
      # property :a, kind_of: [ String, NilClass ]
      # property :a, respond_to: [ ]
      # ```
      #
      # These do not:
      # ```ruby
      # property :a, [ String, nil ], cannot_be: :nil
      # property :a, callbacks: { x: }
      # ```
      #
      # This does not either (accepts nil implicitly only):
      # ```ruby
      # property :a
      # ```
      #
      # @param resource [Chef::Resource] The resource we're coercing against
      #   (to provide context for the coerce).
      # @param name [Symbol] The name of the property we're coercing (to provide
      #   context for the coerce).
      #
      # @return [Boolean] Whether this value explicitly accepts nil.
      #
      # @api private
      def explicitly_accepts_nil?(resource, name)
        return false if !validates_values?

        !validate(resource, name, nil)
      end

      #
      # Specialize this PropertyType by adding or changing some options.
      #
      def specialize(**options)
        options[:is] = [ self ] + (options[:is] || [])
        options[:coerce] = @coerce if defined?(@coerce) && !options.has_key?(:coerce)
        options[:required] = @required if defined?(@required) && !options.has_key?(:coerce)
        options[:name_property] = @name_property if defined?(@name_property) && !options.has_key?(:name_property)
        options[:default] = @default if defined?(@default) && !options.has_key?(:default)
        options[:desired_state] = @desired_state if defined?(@desired_state) && !options.has_key?(:desired_state)
        options[:identity] = @identity if defined?(@identity) && !options.has_key?(:identity)
        self.class.new(options)
      end

      protected

      def error_unless_all_match(errors, value, match_values, message, &matcher)
        if match_values && !match_values.empty?
          match_values.each do |v|
            if !matcher.call(v)
              errors << "value #{value.inspect} #{message} #{v.inspect}"
            end
          end
        end
      end

      def error_unless_any_match(errors, value, match_values, message, &matcher)
        if match_values && !match_values.empty?
          if !match_values.any?(&matcher)
            errors << "value #{value.inspect} #{message} #{english_join(match_values)}"
          end
        end
      end

      def error_unless_callbacks_match(errors, value, callbacks)
        if callbacks && !callbacks.empty?
          callbacks.each do |message, callback|
            if !callback.call(value)
              errors << "Pvalue #{value.inspect} #{message}"
            end
          end
        end
      end

      def english_join(values)
        return '<nothing>' if values.size == 0
        return values[0].inspect if values.size == 1
        "#{values[0..-2].map { |v| v.inspect }.join(", ")} and #{values[-1].inspect}"
      end

      #
      # Whether this resource actually validates values.
      #
      # Returns true if there are any validation options that depend on the
      # actual value.  Does not check for coerce, default, required or
      # name_property.
      #
      # @return [Boolean] Whether this resource validates anything.
      #
      def validates_values?
        # If any validation option exists and *isn't* an empty hash / array, we
        # will indeed spend time validating values.
        %w(is equal_to regex kind_of respond_to cannot_be callbacks).any? do |option|
          send(option) && !send(option).empty?
        end
      end

      def get_value(resource, name)
        resource.instance_variable_get(:"@#{name}")
      end
      def set_value(resource, name, value)
        resource.instance_variable_set(:"@#{name}", value)
      end
      def value_is_set?(resource, name)
        resource.instance_variable_defined?(:"@#{name}")
      end
    end
  end
end
