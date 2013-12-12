{$, View} = require './space-pen-extensions'
telepath = require 'telepath'

### Internal ###
module.exports =
class PaneAxis extends View
  @acceptsDocuments: true

  @deserialize: (state) ->
    new this(state)

  initialize: (args...) ->
    if args[0] instanceof telepath.Document
      @state = args[0]
      @state.get('children').each (child, index) =>
        @addChild(atom.deserializers.deserialize(child), index, updateState: false)
    else
      @state = atom.create(deserializer: @className(), children: [])
      @addChild(child) for child in args

    @state.get('children').on 'changed', ({index, insertedValues, removedValues, siteId}) =>
      return if siteId is @state.siteId
      for childState in removedValues
        @removeChild(@children(":eq(#{index})").view(), updateState: false)
      for childState, i in insertedValues
        @addChild(atom.deserializers.deserialize(childState), index + i, updateState: false)

  addChild: (child, index=@children().length, options={}) ->
    @insertAt(index, child)
    state = child.getState()
    @state.get('children').insert(index, state) if options.updateState ? true
    @getContainer()?.adjustPaneDimensions()

  removeChild: (child, options={}) ->
    options.updateState ?= true

    parent = @parent().view()
    container = @getContainer()
    childWasInactive = not child.isActive?()

    primitiveRemove = (child) =>
      node = child[0]
      $.cleanData(node.getElementsByTagName('*'))
      $.cleanData([node])
      this[0].removeChild(node)

    # use primitive .removeChild() dom method instead of .remove() to avoid recursive loop
    if @children().length == 2
      primitiveRemove(child)
      sibling = @children().view()
      siblingFocused = sibling.is(':has(:focus)')
      sibling.detach()

      if parent.setRoot?
        parent.setRoot(sibling, suppressPaneItemChangeEvents: childWasInactive)
      else
        parent.insertChildBefore(this, sibling, options)
        parent.removeChild(this, options)
      sibling.focus() if siblingFocused
    else
      @state.get('children').remove(@indexOf(child)) if options.updateState
      primitiveRemove(child)

    container.adjustPaneDimensions()
    Pane = require './pane'
    container.trigger 'pane:removed', [child] if child instanceof Pane

  detachChild: (child) ->
    @state.get('children').remove(@indexOf(child))
    child.detach()

  getContainer: ->
    @closest('.panes').view()

  getActivePaneItem: ->
    @getActivePane()?.activeItem

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  insertChildBefore: (child, newChild, options={}) ->
    newChild.insertBefore(child)
    if options.updateState ? true
      children = @state.get('children')
      childIndex = children.indexOf(child.getState())
      children.insert(childIndex, newChild.getState())

  insertChildAfter: (child, newChild) ->
    newChild.insertAfter(child)
    children = @state.get('children')
    childIndex = children.indexOf(child.getState())
    children.insert(childIndex + 1, newChild.getState())

  serialize: ->
    state = @state.clone()
    state.set('children', child.serialize() for child in @children().views())
    state

  getState: -> @state

  horizontalChildUnits: ->
    $(child).view().horizontalGridUnits() for child in @children()

  verticalChildUnits: ->
    $(child).view().verticalGridUnits() for child in @children()
