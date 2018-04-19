module Schedulable
  
  module ActsAsSchedulable

    extend ActiveSupport::Concern
   
    included do
    end
   
    module ClassMethods
      
      def occurrences_association 
        @@occurrences_association 
      end

      def acts_as_schedulable(name, options = {})
        
        name ||= :schedule
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
          
          has_many occurrences_association, options[:occurrences]
          module OccurrencesAssociationBase
            extend ActiveSupport::Concern

            included do
              has_many occurrences_association, options[:occurrences]

              # remaining
              remaining_occurrences_options = options[:occurrences].clone
              remaining_occurrences_association = "remaining_#{occurrences_association}".to_sym
              has_many remaining_occurrences_association, -> { where("#{occurrences_table_name}.date >= ?", Time.current).order('date ASC') }, remaining_occurrences_options
              
              # previous
              previous_occurrences_options = options[:occurrences].clone
              previous_occurrences_association = "previous_#{occurrences_association}".to_sym
              has_many previous_occurrences_association, -> { where("#{occurrences_table_name}.date < ?", Time.current).order('date DESC')}, previous_occurrences_options
 
              # build occurrences for events if we're persisting occurrences.
              def build_occurrences
                min_date = [schedule.date, Time.current].max
                
                # TODO: Make configurable 
                occurrence_attribute = :date 
                
                schedulable = schedule.schedulable
                terminating = schedule.rule != 'singular' && (schedule.until.present? || schedule.count.present? && schedule.count > 1)
                
                max_period = Schedulable.config.max_build_period || 1.year
                max_date = min_date + max_period
                
                max_date = terminating ? [max_date, (schedule.last.to_time rescue nil)].compact.min : max_date
                
                max_count = Schedulable.config.max_build_count || 100
                max_count = terminating && schedule.remaining_occurrences.any? ? [max_count, schedule.remaining_occurrences.count].min : max_count

                # Get schedule occurrence dates
                times = schedule.occurrences_between(min_date.to_time, max_date.to_time)
                times = times.first(max_count) if max_count > 0

                # build occurrences
                occurrences = schedulable.send(occurrences_association)
                times.each do |time|
                  occurrences.find_by_date(time) || occurrences.create(date: time)
                end

                # Clean up unused remaining occurrences 
                self.send("remaining_#{occurrences_association}").where.not(date: times).destroy_all
              end
            end
          end
          Schedule.send :include, OccurrencesAssociationBase
          
          # table_name
          occurrences_table_name = occurrences_association.to_s.tableize
          
          # remaining
          remaining_occurrences_options = options[:occurrences].clone
          remaining_occurrences_association = "remaining_#{occurrences_association}".to_sym
          has_many remaining_occurrences_association, -> { where("#{occurrences_table_name}.date >= ?", Time.current).order('date ASC') }, remaining_occurrences_options
          
          # previous
          previous_occurrences_options = options[:occurrences].clone
          previous_occurrences_association = "previous_#{occurrences_association}".to_sym
          has_many previous_occurrences_association, -> { where("#{occurrences_table_name}.date < ?", Time.current).order('date DESC')}, previous_occurrences_options
          
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
