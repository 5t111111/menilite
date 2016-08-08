require 'sinatra/activerecord'

module Menilite
  module ActiveRecord
    def self.create_model(name)
      self.const_set(name, Class.new(::ActiveRecord::Base))
    end
  end

  class Store
    def initialize
      @tables = {}
      @models = {}
    end

    def self.instance
      @instance ||= Menilite::Store.new
    end

    def register(model_class)
      @tables[model_class] = {}
      @models[model_class] = Menilite::ActiveRecord.create_model(model_class.to_s)
    end

    def find(model_class, id)
      @models[model_class].find_by(guid: id)
    end

    def save(model)
      is_array = model.is_a?(Array)
      models = is_array ? model : [ model ]
      model_class = models.first.class

      models.each do |m|
        obj = find(model_class, m.id)
        if obj
          obj.update!(attributes(m))
        else
          @models[model_class].create!(attributes(m))
        end
      end

      yield model if block_given?
    end

    def fetch(model_class, filter: nil, order: nil)
      assoc = @models[model_class].all

      assoc = assoc.where(filter.entries.to_h) if filter
      assoc = assoc.order([order].flatten.map(&:to_sym)) if order

      yield assoc.map {|m| model_class.new(fields(m)) } || [] if block_given?
    end

    def delete(model_class)
      @models[model_class].delete_all
    end

    def max(model_class, field_name)
      fetch(model_class).max(field_name.to_sym)
    end

    private

    def [](model_class)
      @tables[model_class]
    end

    def attributes(model)
      references = model.class.field_info.values.select{|i| i.type == :reference}
      model.to_h.tap do |hash|
        references.each do |r|
          hash["#{r.name}_guid".to_sym] = hash.delete("#{r.name}_id".to_sym)
        end

        hash[:guid] = hash.delete(:id)
      end
    end

    def fields(ar_obj)
      ar_obj.attributes.tap{|h| h["id"] = h.delete("guid") }
    end
  end
end