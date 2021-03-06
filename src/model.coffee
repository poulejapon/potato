core = require './core'
eventcaster = require './eventcaster'
utils = require './utils'

Integer = core.Literal
    type: 'integer'
    MIN: 0
    MAX: 10
    STEP: 1
    default: 0
    validate: (data)->
        if (typeof data) == "number" and (data == Math.round data)
            { ok: true }
        else
            { ok: false, errors: "#{data} is not an integer" }

String = core.Literal
    type: 'string'
    default: ""
    validate: (data)->
        if (typeof data) == "string"
            { ok: true }
        else
            { ok: false, errors: "Expected a string." }

Boolean = core.Literal
    type: 'boolean'
    default: false
    validate: (data)->
        if (typeof data) == "boolean"
            { ok: true }
        else
            { ok: false, errors: "Boolean expected." }


Enum = String
    type: 'radio'
    default: "yes"
    choices: [ {id: "yes", name: "yes"}, {id: "no", name: "no"}]
    validate: (value)->
        for choice in @choices
            if choice.id == value
                return { ok: true }
        { ok: false, errors: "Enum value <" + value + "> not in " + @choices+ "."}

Model = eventcaster.EventCaster
    
    methods:
        validate: (args...)->
            @__potato__.validate args... 

        destroy: ->
            @trigger "destroy"

        # Returns JSON String describing the state.
        toJSON: ->
            JSON.stringify @toData()
        
        # Returns JSON Object describing the state
        toData: ->
            data = {}
            for k,v of @components()
                data[k] = v.toData @[k]
            data
        
        copy: (obj)->
            @__potato__.make obj
        
        set: (data)->
            if data.__potato__?
                data
            else
                components = @components()
                for componentId, component of components
                    if data[componentId]?
                        this[componentId] = component.set this[componentId], data[componentId]
            @trigger "change"
            this

        find: (elDsl)->
            elDsl = elDsl.trim()
            if elDsl==""
                return this
            if elDsl[0] == "@"
                sep = POTATO_SELECTOR_DSL_SEP.exec(elDsl).index
                head = elDsl[1...sep]
                elDsl = elDsl[sep+1...]
                target = this[head]
                target.find elDsl[1..]
            else
                console.log "Selection DSL for model should start with an @"
                return null
        url: ->
    
    static:
        validate: (data)->
            # Validate works on raw data.
            # My data think JavaScript literals. 
            # Think deserialized JSON.
            validationResult = ok : true
            for cid, component of @components()
                componentValidation = component.validate data[cid]
                if not componentValidation.ok
                    validationResult.ok = false
                    if not validationResult.errors?
                        validationResult.errors = {}
                    validationResult.errors[cid] = componentValidation.errors
            validationResult
        
        # Returns an object from this JSON data.        
        fromJSON: (json)->
            data = JSON.parse json
            @fromData data
        
        fromData: (data)->
            obj = @make()
            @setData obj, data

CollectionOf = (itemType) ->
    Model
        components:
            __items: core.ListOf(itemType)

        methods:
            add: (item)->
                @items().push item
                @trigger "add", item
                @trigger "change"
                if item.bind?
                    item.bind "change", => @trigger "change"
                    item.bind "destroy", => @remove item
                this
            
            remove: (item)->
                nbRemovedEl = utils.removeEl @__items, item, 1
                if nbRemovedEl>0
                    @trigger "change"

            filter: (predicate)->
                els = []
                for el in @items()
                    if predicate(el)
                        els.push el
                els

            items: ->
                @__items

            item: (itemId, value)->
                selectedItem = @__items[itemId]  
                if not value?
                    selectedItem
                else
                    @__items[itemId] = @components().__items.itemType.set selectedItem, value
            
            setData: (data)->
                @__items = []
                for itemData in data
                    @addData itemData
                @trigger "change"
                this

            toData: ->
                @components().__items.toData this.__items
            
            addData: (itemData)->
                @add itemType.fromData itemData

            size: ->
                @__items.length
                
        static:
            validate: (data)->
                validationResult = ok: true
                for itemId, item of data
                    itemValidation = @itemType.validate item 
                    if not itemValidation.ok?
                        if not validationResult.errors?
                            validationResult.errors = {}
                        validationResult.errors[itemId] = itemValidation.errors
                validationResult

model =
    Model: Model
    CollectionOf: CollectionOf
    Integer: Integer
    String: String
    Boolean: Boolean
    Enum: Enum

module.exports = model
