module Pelias

  class Base

    INDEX = 'pelias'

    def initialize(params)
      set_instance_variables(params)
    end

    def save
      attributes = to_hash
      id = attributes.delete('id')
      suggestions = generate_suggestions
      attributes['suggest'] = suggestions if suggestions
      ES_CLIENT.index(index: INDEX, type: type, id: id, body: attributes,
        timeout: '5m')
    end

    def update(params)
      set_instance_variables(params)
    end

    def self.build(params)
      obj = self.new(params)
      obj.set_encompassing_shapes if street_level?
      obj.set_admin_names
      obj
    end

    def self.create(params)
      if params.is_a? Array
        bulk = params.map do |param|
          obj = self.build(param)
          hash = obj.to_hash
          suggestions = obj.generate_suggestions
          hash['suggest'] = suggestions if suggestions
          { index: { _id: hash.delete('id'), data: hash } }
        end
        ES_CLIENT.bulk(index: INDEX, type: type, body: bulk)
      else
        self.build(params)
        obj.save
        obj
      end
    end

    def self.find(id)
      result = ES_CLIENT.get(index: INDEX, type: type, id: id, ignore: 404)
      return unless result
      obj = self.new(:id=>id)
      obj.update(result['_source'])
      obj
    end

    def self.type
      self.name.split('::').last.downcase
    end

    def self.street_level?
      false
    end

    def lat
      center_point[1]
    end

    def lon
      center_point[0]
    end

    def set_encompassing_shapes
      if locality = encompassing_shape('locality')
        self.locality_id = locality['_id']
        source = locality['_source']
        source.delete('center_point')
        source.delete('center_shape')
        source.delete('boundaries')
        source = Hash[source.map { |k,v| ["locality_#{k}", v] } ]
        self.update(source)
      end
      if neighborhood = encompassing_shape('neighborhood')
        self.neighborhood_id = neighborhood['_id']
        source = neighborhood['_source']
        source.delete('center_point')
        source.delete('center_shape')
        source.delete('boundaries')
        source = Hash[source.map { |k,v| ["neighborhood_#{k}", v] } ]
        self.update(source)
      end
    end

    def set_admin_names
      return if country_code.empty? || country_code.nil?
      country = ES_CLIENT.get(index: 'geonames', type: 'country',
        id: country_code, ignore: 404)
      self.country_name = country['_source']['name'] if country
      admin1 = ES_CLIENT.get(index: 'geonames', type: 'admin1',
        id: "#{country_code}.#{admin1_code}", ignore: 404)
      self.admin1_name = admin1['_source']['name'] if admin1
      admin2 = ES_CLIENT.get(index: 'geonames', type: 'admin2',
        id: "#{country_code}.#{admin1_code}.#{admin2_code}", ignore: 404)
      self.admin2_name = admin2['_source']['name'] if admin2
    end

    def generate_suggestions
    end

    def to_hash
      hash ={}
      self.instance_variables.each do |var|
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
      hash.delete_if { |k,v| v=='' || v.nil? || v.empty? }
      hash
    end

    private

    def encompassing_shape(shape_type)
      results = ES_CLIENT.search(index: INDEX, type: shape_type, body: {
        query: {
          filtered: {
            query: { match_all: {} },
            filter: {
              geo_shape: {
                boundaries: {
                  shape: center_shape,
                  relation: 'intersects'
                }
              }
            }
          }
        }
      })
      results['hits']['hits'].first
    end

    def set_instance_variables(params)
      params.keys.each do |key|
        m = "#{key.to_s}="
        self.send(m, params[key]) if self.respond_to?(m)
      end
      true
    end

    def symbolize_keys(hash)
      hash.keys.each do |key|
        hash[(key.to_sym rescue key) || key] = hash.delete(key)
      end
    end

    def type
      self.class.type
    end

    def geo_query
      {
        query: {
          filtered: {
            query: { match_all: {} },
            filter: {
              geo_shape: {
                center_shape: {
                  indexed_shape: {
                    id: @id,
                    type: type,
                    index: INDEX,
                    shape_field_name: 'boundaries'
                  }
                }
              }
            }
          }
        }
      }
    end

  end

end
