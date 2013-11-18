module Pelias

  class Address < Base

    attr_accessor :id
    attr_accessor :number
    attr_accessor :center_point
    attr_accessor :center_shape
    attr_accessor :street_id
    attr_accessor :street_name
    attr_accessor :locality_id
    attr_accessor :locality_name
    attr_accessor :locality_alternate_names
    attr_accessor :locality_population
    attr_accessor :neighborhood_id
    attr_accessor :neighborhood_name
    attr_accessor :neighborhood_alternate_names
    attr_accessor :neighborhood_population
    attr_accessor :country_code
    attr_accessor :country_name
    attr_accessor :admin1_code
    attr_accessor :admin1_name
    attr_accessor :admin2_code
    attr_accessor :admin2_name
    attr_accessor :admin3_code
    attr_accessor :admin4_code

    def self.street_level?
      true
    end

    def generate_suggestions
      # TODO take into account alternate names
      input = "#{@number} #{@street_name}"
      input << "#{@locality_name} #{@locality_admin1_code}"
      output = "#{@number} #{@street_name}"
      output << " - #{@locality_name}" if @locality_name
      output << ", #{@locality_admin1_code}" if @locality_admin1_code
      return {
        input: input,
        output: output,
        payload: { lat: lat, lon: lon, type: type }
      }
    end

  end

end
