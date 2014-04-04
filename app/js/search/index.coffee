angular.module('app.search', [])
  .factory 'SearchResponse', ->
    class SearchResponse
      constructor: (scope, response) ->
        scope.hits = @hits(response)
        console.log _.first scope.hits
        scope.info = @info(response)
        scope.page = @page(response)
        console.log scope.page

      info: (data) ->
        start_index = data.page * data.hitsPerPage
        stop_index = Math.min(start_index + data.hitsPerPage, data.nbHits)
        resp =
          start: Math.min(start_index + 1, data.nbHits)
          stop: stop_index
          time: data.processingTimeMS
          total: data.nbHits

      hits: (data) ->
        data.hits

      page: (data) ->
        current = data.page
        resp =
          current: current
          prev: current - 1
          hasPrev: current != 0
          hasNext: current < data.nbPages - 1
          next: current + 1

  .service 'Library', (AlgoliaIndex, $location, SearchResponse) ->
    index = new AlgoliaIndex('jsdelivr')

    class Library
      get: (id, params) ->
        index.getObject(id, params)
      search: (scope) ->
        state = $location.search()
        params =
          hitsPerPage: 25
          facets: ['*']
          maxValuesPerFacet: 10
          facetFilters: []
          attributesToRetrieve: ['description', 'name', 'lastversion']
          q: state.q

        params.page = state.page if state.page
        scope.hits = null
        index.search(params).then (response) ->
          new SearchResponse(scope, response)
    new Library()

  .service 'Collection', ($localForage, $rootScope) ->
    $rootScope.collection ||= {}
    $localForage.bind($rootScope, 'collection')

    class Collection
      add: (lib, file) ->
        $rootScope.collection[lib.name] ||=
          version: lib.selected_version
          files: []

        if $rootScope.collection[lib.name].version != lib.selected_version
          throw "Version already in collection"

        $rootScope.collection[lib.name].files.push file if $rootScope.collection[lib.name].files.indexOf(file) == -1

    new Collection()

  .controller 'DetailCtrl', ($scope, $stateParams, Library, Collection) ->
    $scope.add_to_collection = (lib, file) ->
      Collection.add(@lib, @file)

    Library.get($stateParams.name).then (res) ->
      res.selected_version = res.lastversion
      res.assets = _.indexBy(res.assets, 'version')
      $scope.lib = res

    $scope.file_url = ->
      "//cdn.jsdelivr.net/#{@lib.selected_version}/#{@file}"


  .controller 'SearchCtrl', ($scope, $location, Library) ->
    $scope.search = $location.search().q
    Library.search($scope)

    $scope.reset = ->
      $location.search({})
      Library.search($scope)

    $scope.select = (param_key, value) ->
      $location.search('page', null)
      value = null if value == ""
      $location.search(param_key, value)
      Library.search($scope)

    $scope.select_page = (page) ->
      return if page < 0
      page = null if page == 0
      $location.search('page', page)
      Library.search($scope)
