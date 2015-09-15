# Gives us `EventTarget` functionality, for dispatching change events.
EventTargetMixin = require 'oo-eventtarget'

# simple implementation of lodash's `_.extend`
extend = (obj, fields) ->
  result = {}
  for key, value of obj
    result[key] = value
  for key, value of fields
    result[key] = value

  return result

###
Represents nested data as an ordered tree structure. Provides support for
mutation observation. Can be used in conjunction with `TreeTransformer` to
lazily and automatically transform between different tree representations.
###
class TreeModel
  ###
  Constructs a `TreeModel` with an optional value to hold.

  @param [a] value This node's held value.
  ###
  constructor: (@value) -> @_mutate () =>
    # mixin EventTarget functionality
    EventTargetMixin this

    ###
    @property [Array] Mapping of keys to this node's children, in the form:
      node: TreeModel
      key: String
    ###
    @_children = {}

    ###
    @property [Array<String>] An ordered list of keys for this node's children.
    ###
    @orderedChildrenKeys = []

    ###
    @property [Array<TreeModel>] An ordered list of this node's children.
    ###
    Object.defineProperty this, 'childList',
      get: () ->
        @orderedChildrenKeys.map (key) => @_children[key].node

  ###
  @property [TreeModel] This node's parent node, or `null` if root.
  ###
  parent: null

  ###
  @property [String] The key by which this node's parent refers to this node,
    or `null` if root.
  ###
  key: null


  ##### Child operations #####

  ###
  @param [String] key
  @return [TreeModel] The specified child node, or `null` if no such child.
  ###
  getChild: (key) ->
    if @_children[key]?
    then @_children[key].node
    else null

  ###
  Returns the index of the specified child, or `null` if no such child.

  @param [String] key
  @return [Integer] The index of the child at `key`, or `null` if no such child.
  ###
  getIndexOfChild: (key) ->
    if @_children[key]?
    then @_children[key].index
    else null

  ###
  @param [String] key
  @param [TreeModel] node
  ###
  addChild: (key, node) -> @_mutate () =>
    if not key?
      return null

    @removeChild key

    node.parent = this
    node.key = key
    node.addEventListener 'changed', (@_bubble key)

    @orderedChildrenKeys.push key
    index = @orderedChildrenKeys.length - 1
    @_children[key] =
      node: node
      index: index

    return @_children[key].node


  ###
  If a child exists at the specified key, replaces the child node at `key` with
    the specified node.
    If no such child exists, adds the node as a child at the specified key.

  @param [String] key The child's key.
  @param [TreeModel] node The node to put in the existing child's place.
  @return [TreeModel] The "adopted" child node (`node`)
  ###
  setChild: (key, node) ->
    if @_children[key]?
    then @_mutate () => @_children[key].node = node
    else @addChild key, node


  ###
  @param [String] key Key of child to be removed.
  @return [TreeModel] The removed child.
  ###
  removeChild: (key) ->
    if @_children[key]?
      toDelete = @_children[key]

      @_mutate () => toDelete.node._mutate () =>
        toDelete.node.removeEventListener 'changed', (@_bubble key)
        toDelete.node.parent = null
        toDelete.node.key = null

        @orderedChildrenKeys.splice @_children[key].index, 1
        delete @_children[key]

        reorderChildren = (startIndex) =>
          for i in [startIndex...@orderedChildrenKeys.length]
            @_children[@orderedChildrenKeys[i]].index = i
        reorderChildren toDelete.index

        return toDelete.node

  ###
  Alias for `removeChild`.

  @param [String] key Key of child to be detached.
  @return [TreeModel] The detached child.
  ###
  detach: () -> @removeChild arguments...


  ##### Tree operations #####

  ###
  Creates a new node and places it at the provided path.

  Note: This is a mutating method, but the mutation is delegated to the
  new node's parent via `addChild`.

  @param [Array<String>] path The path where the new node should live.
  @param [a] value The value to be placed in the new node.
  @return [TreeModel<a>] The newly-created node, or `null` if invalid path.
  ###
  put: ([parentPath..., key], value) ->
    parent = @navigate parentPath
    if parent? and key?
    then parent.addChild key, (new TreeModel value)
    else
      if not key?
        throw new RangeError 'Attempted to put value at an undefined key.'
      else if not parent?
        throw new RangeError 'Attempted to put value at invalid path.'

  ###
  Navigates to a node and returns that node if it exists.

  @param [Array<String>] path A path to the node, with the node's key as the last element.
  @return [TreeModel] The specified node, or `null` if no such node.
  ###
  navigate: (path) ->
    [hd, tl...] = path
    switch
      when hd?
        (@getChild hd)?.navigate tl
      else
        return this

  ###
  Removes all children from this node.

  @return [TreeModel] This model.
  ###
  clear: () -> @_mutate () =>
    @orderedChildrenKeys.forEach (key) =>
      @removeChild key
    return this


  ###
  Walks the tree depth-first, in order according to each node's `childList`,
    reducing to a single value.

  @param [Function<a, b, a>] procedure The reduction procedure, taking
    as parameters the accumulator value, and the current node's value; and
    returning the updated accumulator value.
  @param [a] accumulator The initial accumulator value.
  ###
  reduce: (procedure, accumulator) ->
    @childList.forEach (child) ->
      accumulator = child.reduce procedure, accumulator
    procedure accumulator, @value


  # ###
  # Provides mechanism to reduce the tree in a specific order.

  # @param [Function<a, TreeModel, Array<TreeModel>, Function<a, TreeModel, a>, a>] procedure
  # @param [a] accumulator
  # ###
  # reduceWithOrder: (procedure, accumulator) ->
  #   procedure accumulator, this, @childList, (node) ->
  #     procedure accumulator, node, node.childList


  # TODO: some shit w generators? how to give full easy control here
  #
  # # example usage?
  # tree.reduceWithOrder (acc, node, children, cont) ->
  #   acc[node.id] = node
  #   children.forEach (child) ->
  #     acc = cont acc, child

  ##### Utility #####

  ###
  ###
  batchMutate: (proc) -> @_mutate () => proc this

  ###
  Performs a mutation action, sending off changed events.

  @param [Function] procedure The action to perform.
  @return [?] The result of procedure.
  ###
  _mutate: (procedure) ->
    # check if we're being called _inside of_ a mutating method
    if not @_isMutating
      @_isMutating = true
      r = do procedure
      @_fireChanged()
      @_isMutating = false
      return r
    else
      do procedure


  ##### Communication #####

  ###
  Fires a changed event.

  @param [TreeModel] node The changed node.
  ###
  _fireChanged: () ->
    
    @dispatchEvent 'changed',
      node: this
      path: []

  _bubble: (childKey) => (evt) =>
    # If this node receives a change event from a child while mutating,
    #   we can just ignore it, since we'll need to send a change event
    #   for this node's mutation anyways.
    if not @_isMutating
      data = extend evt.data, path: [childKey, evt.data.path...]
      @dispatchEvent evt.type, data


module.exports = TreeModel