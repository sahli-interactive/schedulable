module Schedulable
  
  module ActsAsSchedulable

    extend ActiveSupport::Concern
   
    included do
    end
   
    module ClassMethods
      
      def acts_as_schedulable(name, options = {})
        
        name ||= :schedules
        attribute = :date
        
        has_many name, as: :schedulable, dependent: :destroy, class_name: 'Schedule'
        accepts_nested_attributes_for name
        
        if options[:occurrences]
          
          # setup association
          if options[:occurrences].is_a?(String) || options[:occurrences].is_a?(Symbol)
            occurrences_association = options[:occurrences].to_sym
            options[:occurrences] = {}
          else
            occurrences_association = options[:occurrences][:name]
            options[:occurrences].delete(:name)
          end
          options[:occurrences][:class_name] = occurrences_association.to_s.classify
          options[:occurrences][:as]||= :schedulable
          options[:occurrences][:dependent]||:destroy
          options[:occurrences][:autosave]||= true
          
          # table_name
          occurrences_table_name = occurrences_association.to_s.tableize
          
          has_many occurrences_association, options[:occurrences] do
            def remaining
              where("#{occurrences_table_name}.date >= ?", Time.current).order('date ASC')
            end

            def previous
              where("#{occurrences_table_name}.date < ?", Time.current).order('date DESC')
            end
          end
          
          ActsAsSchedulable.add_occurrences_association(self, occurrences_association)
        end
      end
  
    end
    
    def self.occurrences_associations_for(clazz)
      @@schedulable_occurrences||= []
      @@schedulable_occurrences.select { |item|
        item[:class] == clazz
      }.map { |item|
        item[:name]
      }
    end
    
    private
    
    def self.add_occurrences_association(clazz, name)
      @@schedulable_occurrences||= []
      @@schedulable_occurrences << {class: clazz, name: name}
    end
    
      
  end
end  
ActiveRecord::Base.send :include, Schedulable::ActsAsSchedulable
