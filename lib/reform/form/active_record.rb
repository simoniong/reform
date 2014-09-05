module Reform::Form::ActiveRecord
  def self.included(base)
    base.class_eval do
      register_feature Reform::Form::ActiveRecord
      include Reform::Form::ActiveModel
      extend ClassMethods
    end
  end

  module ClassMethods
    def validates_uniqueness_of(attribute, options={})
      options = options.merge(:attributes => [attribute])
      validates_with(UniquenessValidator, options)
    end
    def i18n_scope
      :activerecord
    end

    # validations/with
    class Validuff
      def initialize(validator)
        @validator = validator
      end

      def validate(form, *args)
        # after instantiating a Validator, Rails also calls validator.setup(model.class). I tried to change this years ago in rails-core but it wasn't accepted.
        @validator.instance_variable_set(:@klass, form.model.class) # this is why we need to change Rails.
        @validator.validate(Facade.new(form))
      end
    end
    def validate(validator, options)
      return super unless validator.is_a? UniquenessValidator
      # validator is already with #setup called.
      super(Validuff.new(validator), options)
    end

    class Facade
      def initialize(form)
        @form, @model = form, form.model # TODO: get particular model for Composition
      end

      def method_missing(name, *args, &block)
        form_readers = @form.send(:mapper).representable_attrs[:definitions].keys
        form_readers << "errors"
        return @form.send(name) if form_readers.include?(name.to_s)
        if name.to_s == "read_attribute_for_validation"
          puts "--- #{args.first}... #{@form.send(args.first) }"
          return @form.send(args.first)

        end

        puts "??????????? #{@model.inspect}"
        puts "#{name}, #{args.inspect} --> #{@model.send(name, *args, &block)}"
        @model.send(name, *args, &block)
      end

      def class
        @model.class
      end
    end
  end

  # TODO: remove.
  class UniquenessValidator < ::ActiveRecord::Validations::UniquenessValidator
  end


  def model_for_property(name)
    return model unless is_a?(Reform::Form::Composition) # i am too lazy for proper inheritance. there should be a ActiveRecord::Composition that handles this.

    model_name = mapper.representable_attrs.get(name)[:on]
    model[model_name]
  end

  # Delegate column for attribute to the model to support simple_form's
  # attribute type interrogation.
  def column_for_attribute(name)
    model_for_property(name).column_for_attribute(name)
  end
end
