util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
inflection = require 'inflection'

Utils = require 'backbone-orm/utils'
One = require 'backbone-orm/lib/relations/one'

module.exports = class SqlOne extends One

  get: (model, key, callback, _get) ->
    if key is @ids_accessor
      related_id = if related_model = model.attributes[@key] then related_model.get('id') else null
      callback(null, related_id) if callback
      return related_id
    else
      throw new Error "HasOne::get: Unexpected key #{key}. Expecting: #{@key}" unless key is @key
      if value = model.attributes[key]

        # needs load
        if value._orm_needs_load
          query = {$one: true}

          console.log "value: #{util.inspect(model.attributes)}"

          query.id = (value.get?('id') or value.id) if @type is 'belongsTo'
          query[@foreign_key] = model.attributes.id if @type is 'hasOne'

          @reverse_model_type.cursor(query).limit(1).toModels (err, related_model) =>
            return callback(err) if err
            return callback(new Error "Model not found. Id #{util.inspect(query)}") if not related_model

            # update
            delete value._orm_needs_load
            model.set(key, related_model)
            @reverse_model_type._cache.markLoaded(value) if @reverse_model_type._cache
            callback(null, related_model)
          return

      callback(null, value) if callback
      return value

  set: (model, key, value, options) ->
    # TODO: Allow sql to sync...make a notification? use Backbone.Events?
    key = @key if key is @ids_accessor

    throw new Error "HasOne::set: Unexpected key #{key}. Expecting: #{@key}" unless key is @key
    return @ if @has(model, key, value) # already set

    # clear reverse
    if @reverse_relation
      if @has(model, key, value) and (related_model = model.attributes[@key])
        if @reverse_relation.remove
          @reverse_relation.remove(related_model, model)
        else
          related_model.set(@reverse_relation.key, null)

    related_model = if value then Utils.createRelated(@reverse_model_type, value) else null

    # TODO: Allow sql to sync...make a notification? use Backbone.Events?
    # _set.call(model, @foreign_key, related_model.attributes.id, options) if @type is 'belongsTo'
    # _set.call(related_model, @foreign_key, model.attributes.id, options) if @type is 'hasOne'

    Backbone.Model::set.call(model, key, related_model, options)
    return @ if not related_model or not @reverse_relation

    if @type is 'hasOne'
      if @reverse_relation.add
        @reverse_relation.add(related_model, model)
      else
        related_model.set(@reverse_relation.key, model)

    return @

  has: (model, key, item) ->
    current_related_model = model.attributes[@key]
    return false if (current_related_model and not item) or (not current_related_model and item)

    # compare ids
    current_id = current_related_model.get('id') if current_related_model instanceof Backbone.Model
    return current_id is item.get('id') if item instanceof Backbone.Model
    return current_id is item.id if _.isObject(item)
    return current_id is item
