TreeModel = require '../../build/TreeModel.js'


treeInvariants = (model) ->
  # This `expect` might change, since it's relying on the private
  #   field `_children` - but seems important to test whether the
  #   tree is holding onto orphaned children.
  expect model.orderedChildrenKeys.length
    .toBe Object.keys(model._children).length

  model.orderedChildrenKeys.forEach (key, idx) ->
    expect model.getChild(key)
      .toBeDefined()
    expect model.getIndexOfChild(key)
      .toBe idx

    # This also might change.
    # Something seems off about keeping information about the node's ancestors
    #   in the node proper...
    expect model.getChild(key).parent
      .toBe model
    expect model.getChild(key).key
      .toBe key

    treeInvariants model.getChild(key)



describe 'Basic tree model', () ->
  beforeEach () ->
    @tree = new TreeModel {foo: 3, name: 'root'}

  it 'can put values', () ->
    @tree.put ['a'], {name: 'a'}
    @tree.put ['b'], {name: 'b'}
    @tree.put ['c'], {name: 'c'}

    treeInvariants @tree

    expect @tree.childList.length
      .toBe 3
    expect @tree.getChild('a').value
      .toEqual {name: 'a'}
    expect @tree.getChild('c').value
      .toEqual {name: 'c'}

    @tree.put ['a', 'a'], {name: 'aa'}
    @tree.put ['a', 'b'], {name: 'ab'}

    treeInvariants @tree

    expect @tree.childList.length
      .toBe 3
    expect @tree.getChild('a').value
      .toEqual {name: 'a'}

    expect @tree.getChild('a').childList.length
      .toBe 2
    expect @tree.getChild('a').getChild('a').value
      .toEqual {name: 'aa'}
    expect @tree.getChild('a').getChild('b').value
      .toEqual {name: 'ab'}

    invalidPutPath = () =>
      @tree.put ['a', 'b', 'nonexistant', 'oliver'], {name: 'batman'}
    emptyPutPath = () =>
      @tree.put [], {name: 'batman'}
    expect invalidPutPath
      .toThrowError RangeError
    expect emptyPutPath
      .toThrowError RangeError



  it 'fires change events', () ->
    spy = jasmine.createSpy 'changedCallback'

    @tree.addEventListener 'changed', spy

    expect spy
      .not.toHaveBeenCalled()

    node = @tree.put ['a'], {name: 'a'}
    treeInvariants @tree

    expect spy.calls.count()
      .toBe 1
    spy.calls.reset()

    deleted = @tree.removeChild 'a'
    treeInvariants @tree

    expect deleted
      .toBe node
    expect spy.calls.count()
      .toBe 1
    spy.calls.reset()

    @tree.put ['b'], {name: 'b'}
    # treeInvariants @tree
    expect spy.calls.count()
      .toBe 1
    spy.calls.reset()
    @tree.clear()
    # treeInvariants @tree
    expect spy.calls.count()
      .toBe 1
    spy.calls.reset()


  it 'bubbles change events', () ->
    # Add children.
    a = @tree.put ['a'], {name: 'a'}
    b = @tree.put ['a', 'b'], {name: 'b'}

    # Register spy as change callback on child.
    childSpy = jasmine.createSpy 'changedCallback'
    b.addEventListener 'changed', childSpy
    expect childSpy
      .not.toHaveBeenCalled()

    # Register spy as change callback on root.
    rootSpy = jasmine.createSpy 'changedCallback'
    @tree.addEventListener 'changed', rootSpy
    expect rootSpy
      .not.toHaveBeenCalled()

    b.put ['c'], {name: 'c'}
    expect childSpy.calls.count()
      .toBe 1
    expect childSpy.calls.argsFor(0)[0].data.node
      .toBe b

    expect rootSpy.calls.count()
      .toBe 1
    expect expect rootSpy.calls.argsFor(0)[0]
      .toBeDefined()
    expect rootSpy.calls.argsFor(0)[0].data.node
      .toBe b

    childSpy.calls.reset()
    rootSpy.calls.reset()

    d = @tree.put ['a', 'd'], {name: 'd'}
    expect childSpy.calls.count()
      .toBe 0
    expect rootSpy.calls.count()
      .toBe 1
    expect rootSpy.calls.argsFor(0)[0].data.node
      .toBe a

  it 'keeps child order through mutations', () ->
    @tree.put ['a'], {name: 'a'}
    @tree.put ['a', 'b'], {name: 'b'}
    @tree.put ['a', 'c'], {name: 'c'}
    @tree.put ['a', 'd'], {name: 'd'}
    @tree.put ['a', 'e'], {name: 'e'}

    treeInvariants @tree
    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'd', 'e']

    @tree.put ['a', 'd', 'f'], {name: 'f'}

    treeInvariants @tree
    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'd', 'e']

    @tree.navigate(['a']).removeChild 'd'

    treeInvariants @tree
    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'e']

    subtree = new TreeModel {name: 'g'}
    subtree.put ['h'], {name: 'h'}
    subtree.put ['i'], {name: 'i'}
    subtree.put ['h', 'j'], {name: 'j'}

    @tree.navigate(['a', 'b']).addChild 'g', subtree

    treeInvariants @tree
    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'e']
    expect @tree.navigate(['a', 'b', 'g']).orderedChildrenKeys
      .toEqual ['h', 'i']


  it 'maintains good structure under stress', () ->
    @tree.put ['a'], {name: 'a'}
    @tree.put ['a', 'b'], {name: 'b'}
    @tree.put ['a', 'c'], {name: 'c'}
    @tree.put ['a', 'd'], {name: 'd'}
    @tree.put ['a', 'e'], {name: 'e'}
    @tree.put ['a', 'd', 'f'], {name: 'f'}
    @tree.put ['a', 'd', 'g'], {name: 'g'}
    @tree.put ['a', 'd', 'f', 'h'], {name: 'h'}

    treeInvariants @tree

    d =
      @tree
        .navigate ['a']
        .detach 'd'

    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'e']
    expect d.parent
      .toBeNull()
    expect d.key
      .toBeNull()
    treeInvariants @tree

    e = @tree.navigate(['a', 'e'])
    e.addChild 'd2', d

    expect @tree.getChild('a').orderedChildrenKeys
      .toEqual ['b', 'c', 'e']
    expect e.orderedChildrenKeys
      .toEqual ['d2']
    treeInvariants @tree

    d2 = e.detach 'd2'
    f = d2.detach 'f'

    f.addChild 'd3', d2
    treeInvariants f

    @tree.addChild 'f2', f
    expect @tree.orderedChildrenKeys
      .toEqual ['a', 'f2']
    treeInvariants @tree


  it 'can reduce trees', () ->
    @tree.put ['a'], {name: 'a'}
    @tree.put ['a', 'b'], {name: 'b'}
    @tree.put ['a', 'c'], {name: 'c'}
    @tree.put ['a', 'd'], {name: 'd'}
    @tree.put ['a', 'e'], {name: 'e'}
    @tree.put ['a', 'd', 'f'], {name: 'f'}
    @tree.put ['a', 'd', 'g'], {name: 'g'}
    @tree.put ['a', 'd', 'f', 'h'], {name: 'h'}

    reduction = (acc, elm) ->
      acc += elm.name
      return acc
    result = @tree.reduce reduction, ''

    expect result
      .toBe 'bchfgdearoot'


  it 'can calculate paths', () ->
    @tree.put ['a'], {name: 'a'}
    @tree.put ['a', 'b'], {name: 'b'}
    @tree.put ['a', 'c'], {name: 'c'}
    d = @tree.put ['a', 'd'], {name: 'd'}
    @tree.put ['a', 'e'], {name: 'e'}
    @tree.put ['a', 'd', 'f'], {name: 'f'}
    @tree.put ['a', 'd', 'g'], {name: 'g'}
    h = @tree.put ['a', 'd', 'f', 'h'], {name: 'h'}

    expect (@tree.navigate h.getPathToRoot())
      .toBe h
    expect (@tree.navigate d.getPathToRoot())
      .toBe d

    expect (d.navigate h.getPathRelativeTo(d))
      .toBe h
    backwards = () -> d.getPathRelativeTo h
    expect backwards
      .toThrow()
