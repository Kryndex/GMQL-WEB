@gmql = "gmql values"
ucscBaseLink = "http://genome.ucsc.edu/cgi-bin/hgTracks?org=human&hgt.customText="
$ ->
#  $(window).resize ->
#    $("#tree-panel").height $(window).height()

$ ->
  $('[data-toggle="tooltip"]').tooltip()
  $('#button-expand-all').click ->
    $(this).focusout()
    $('#tree').fancytree('getTree').visit (node) ->
      node.setExpanded true
  $('#button-collapse-all').click ->
    $(this).focusout()
    $('#tree').fancytree('getTree').visit (node) ->
      node.setExpanded false
  initTree()
  $("#refresh-tree").click ->
    $(this).focusout()
    initTree()
    console.log("refresh tree")


  $('#button-delete-data-set').click ->
    deleteSelectedNodes()
  $('#button-download-data-set').click ->
    downloadDataset()
  $('#button-ucsc-data-set').click ->
    loadUcsc()


@resetPrivate = ->
  $("#tree").fancytree("getRootNode").children[0].resetLazy()
  expandPrivate()

expandPrivate = ->
  $("#tree").fancytree("getRootNode").children[0]?.setExpanded(true)

glyph_opts = map:
  doc: 'glyphicon glyphicon-folder-close'
  docOpen: 'glyphicon glyphicon-folder-open'
  checkbox: 'glyphicon glyphicon-unchecked'
  checkboxSelected: 'glyphicon glyphicon-check'
  checkboxUnknown: 'glyphicon glyphicon-share'
  dragHelper: 'glyphicon glyphicon-play'
  dropMarker: 'glyphicon glyphicon-arrow-right'
  error: 'glyphicon glyphicon-warning-sign'
  expanderClosed: 'glyphicon glyphicon-menu-right'
  expanderLazy: 'glyphicon glyphicon-menu-right'
  expanderOpen: 'glyphicon glyphicon-menu-down'
  folder: 'glyphicon glyphicon-plus'
  folderOpen: 'glyphicon glyphicon-minus'
  loading: 'glyphicon glyphicon-refresh glyphicon-spin'

@initTree = ->
# TODO change with http://wwwendt.de/tech/fancytree/demo/#sample-webservice.html
# Initialize Fancytree
  $('#tree').fancytree
    extensions: [
      'glyph'
    ]
    checkbox: true

    glyph: glyph_opts
    selectMode: 3
    source: [
      {
        title: "Private"
        "folder": true
        "lazy": true
        hideCheckbox: true
        unselectable: true
        type: "main"
        value: "private-data-set"
      }
      {
        title: "Public"
        "folder": true
        "lazy": true
        hideCheckbox: true
        unselectable: true
        type: "main"
        value: "public-data-set"
      }
    ]

    toggleEffect:
      effect: 'drop'
      options:
        direction: 'left'
      duration: 400
    wide:
      Width: '1em'
    iconSpacing: '0.5em'
    levelOfs: '1.5em'
#    I cannot use this icon!!!
#    icon: (event, data) ->
#      console.log("ASD")
#      'glyphicon glyphicon-book'


    lazyLoad: (event, data) ->
      window.lastNode = data.node
      console.log(data)

      dfd = $.Deferred();
      data.result = dfd.promise();
      if /main/.test data.node.data.type
        call = jsRoutes.controllers.gmql.DSManager.dataSetAll()
      else
        call = jsRoutes.controllers.gmql.DSManager.dataSetSamples(data.node.data.value)
      console.log {'X-Auth-Token': window.authToken}
      $.ajax
        url: call.url
        type: call.type
        method: call.method
        headers: {'X-Auth-Token': window.authToken}
        contentType: 'json'
        dataType: 'json'
        success: (result, textStatus, jqXHR) ->
          if "main" == data.node.data.type
            newType = "data-set"
            lazy = true
            if "public-data-set" == data.node.data.value
              console.log "public"
              list = result.attributeList.attribute.filter (x) -> x.name.startsWith("public")
            else
              console.log "private"
              list = result.attributeList.attribute.filter (x) -> not (x.name.startsWith("public"))
          else
            newType = "sample"
            lazy = false
            window.list = list
            iconclass = "glyphicon glyphicon-file"
            list = result.attributeList.attribute

          res = for att in list
            hideCheckBox = ("public-data-set" == data.node.data.value) || ("public-data-set" == data.node.parent?.data.value)
            temp = {
              key: if newType == "data-set" then att.name.replace /^public\./, "" else att.name.split("/").pop()
              title: if newType == "data-set" then att.name.replace /^public\./, "" else att.name.split("/").pop()
              folder: false
              lazy: lazy
              hideCheckbox: hideCheckBox
              unselectable: hideCheckBox
              type: newType
              value: att.name
              selected: data.node.selected
            }
            temp.iconclass = iconclass if iconclass
            temp.id = att.id if att.id
            temp
          dfd.resolve(res)
      window.lastNode.setActive()

    select: (event, data) ->
      logEvent event, data, 'current state=' + data.node.isSelected()
      s = data.tree.getSelectedNodes().join(', ')
      $('#echoSelected').text s
      console.log 'select'
      data.node.setActive()

    activate: (event, data) ->
      logEvent event, data
      node = data.node
      window.activeNode = node
      $('#echoActive').text node.title + " val " + data.node.data.value
      setDataSetSchema(node)
      setSampleMetadata(node)
      console.log 'activate'

    beforeActivate: (event, data) ->
      window.beforeActivate = data.node
      console.log 'beforeActivate'
      logEvent event, data
      if generateQuery()
        BootstrapDialog.confirm 'Are sure to change the data set, query in the metadata browser will be lost?', (result) ->
          if result
#            alert 'Yup.'
            $(".del-button").click()

            data.node.setActive()
          else
#            alert 'Nope.'
        return false


setSampleMetadata = (node) ->
  dataSet = node.parent.data.value
  id = node.data.id
  metadataDiv = $("#metadata-div")
  metadataDiv.empty()

  if(node.data.type == "sample")
#    metadataDiv.append "<h2>Sample metadata #{if node.title?.length then "of " + node.title else "" }</h2>"
    insertMetadataTable(metadataDiv, dataSet, id)


setDataSetSchema = (node) ->
  data = node.data
  type = data.type
  value =
    switch type
      when "sample"   then node.parent.data.value
      when "data-set"  then data.value


  if value?
    if window.lastSelectedDataSet != value
      call = jsRoutes.controllers.gmql.RepositoryBro.dataSetSchema(value)
      $.ajax
        url: call.url
        type: call.type
        method: call.method
        headers: {'X-Auth-Token': window.authToken}
        contentType: 'json'
        dataType: 'json'
        success: (result, textStatus, jqXHR) ->
          $('#echoActive').text node.title + " val " + JSON.stringify(result.schemas, null, "\t")
          window.result = result
          window.lastSelectedDataSet = value
          schemaTables(result)
          clearMetadataDiv()
          if generateQuery?
            generateQuery()
          else
            alert 'generateQuery is not defined'

  else
    clearMetadataDiv()
    generateQuery()
    $('#echoActive').text node.title + " val " + data.value
    #        $("#schema-div").hide()
    $("#schema-div").empty()
    window.lastSelectedDataSet = null


schemaTables = (result)->
  schemas = result.gmqlSchemaCollection.gmqlSchema
  schemaDiv = $("#schema-div")
  #  schemaDiv.show()
  schemaDiv.empty()
  #  schemaDiv.append "<h2>DataSet schemas #{if result.gmqlSchemaCollection.name?.length then "of " + result.gmqlSchemaCollection.name else "" }</h2>"
  for schema in schemas
    schemaDiv.append schemaTable(schema)

schemaTable = (schema) ->
  div = $("<div id='schema-table-div-#{schema.name}'>")
  div.append "<h4><b>Schema name:</b> #{schema.name}</h4>" if schema.name?.length
  div.append "<h4><b>Schema type:</b> #{schema.type}</h4>" if schema.type?.length
  div.append table = $("
            <table id='schema-table-#{schema.name}' class='table table-striped table-bordered'>
                <thead>
                    <tr>
                        <th>Field name</th>
                        <th>Field type</th>
                        <th>Heat map</th>
                    </tr>
                </thead>
            </table>")

  table.append tbody = $("<tbody>")
  for x in schema.field
    newRow = $("<tr>").append($("<td>").text(x.value)).append($("<td>").text(x.type))
    if x.value not in ["seqname", "feature", "start", "end"] and x.type not in ["STRING",
      "CHAR"] and not /^public\./.test window.lastSelectedDataSet
      link = jsRoutes.controllers.gmql.DSManager.parseFiles(window.lastSelectedDataSet, x.value).url
      button = $("<a target='_blank' href='#{link}' class='btn btn-default btn-xs'>View</a>")
      newRow.append($("<td>").append(button))
    else
      newRow.append($("<td>").text(""))
    tbody.append newRow
  div


logEvent = (event, data, msg) ->
#        var args = $.isArray(args) ? args.join(", ") :
  msg = if msg then ': ' + msg else ''
  $.ui.fancytree.info "Event('" + event.type + '\', node=' + data.node + ')' + msg


deleteSelectedNodes = ->
  selectedNodes = findSelectedNode()
  window.selectedNode = selectedNodes
  console.log "selectedNode: "
  console.log selectedNodes
  dataSetsDiv = (selectedNodes.data_sets.map (node) -> "<div>#{node.title}</div>").join('')

  samplesDiv = (selectedNodes.samples.map (node) -> "<div>#{node.parent.title} -> #{node.title} </div>").join('')
  console.log dataSetsDiv

  if dataSetsDiv.length + samplesDiv.length > 0
    BootstrapDialog.show
      message: '<div>Are you sure to delete? </div>' +
        (("<b>Data sets:</b>#{dataSetsDiv}" if dataSetsDiv.length) or '') +
        (("<b>Samples:</b>#{samplesDiv}" if samplesDiv.length) or '') +
        (("<div>Sample deletion is not implemented, yet</div>" if samplesDiv.length) or '')
      buttons: [
        {
          label: 'Delete'
          cssClass: 'btn-danger'
          icon: 'glyphicon glyphicon-trash'
          action: (dialogItself) ->
            startDelete selectedNodes
            dialogItself.close()
        }
        {
          label: 'Cancel'
          action: (dialogItself) ->
            dialogItself.close()

        }
      ]
  else
    BootstrapDialog.alert "No data set or sample selected!"

findSelectedNode = ->
  nodes = $('#tree').fancytree('getRootNode').tree.getSelectedNodes()
  uniqueDataSetNodes = []
  uniqueSampleNodes = []
  for node in nodes
    if node.data.type == "data-set"
      console.log "data-set" + node.data.type
      console.log node
      uniqueDataSetNodes.push node
    else if node.data.type == "sample"
      if not (node.parent in nodes)
        uniqueSampleNodes.push node
        console.log "samples" + node.data.type
        console.log node
  {data_sets: uniqueDataSetNodes, samples: uniqueSampleNodes}


startDelete = (selectedNodes) ->
  for node in selectedNodes.data_sets
    deleteDataset(node)


deleteDataset = (node) ->
  console.log("data-set-sample.clicked")
  call = jsRoutes.controllers.gmql.DSManager.dataSetDeletion(node.title)
  $.ajax
    url: call.url
    type: call.type
    method: call.method
    headers: {'X-Auth-Token': window.authToken}
    success: (result, textStatus, jqXHR) ->
      displayInfo(result)
      #      BootstrapDialog.show
      #        message: "Data set(#{node.title}) is deleted"
      $.notify({
        title: '<strong>Deleted</strong>',
        message: "Data set(#{node.title}) is deleted"
      }, {
        type: 'success'
        placement: {
          align: "left"
          from: "top"
        }
        delay: 1000
      });

      resetPrivate()
    error: (jqXHR, textStatus, errorThrown) ->
      console.log("error" + textStatus)
      BootstrapDialog.alert "#{node.title} cannot be deleted"
      resetPrivate()

downloadDataset = () ->
  console.log(".clicked")
  if window.lastSelectedDataSet.startsWith("public.")
    BootstrapDialog.alert "Public dataset is not available to download"
  else
    dialog = BootstrapDialog.alert "Download file is preparing, please wait"
    window.lastDownloadDataSet = window.lastSelectedDataSet
    call = jsRoutes.controllers.gmql.DSManager.zipFilePreparation window.lastSelectedDataSet, false
    $.ajax
      url: call.url
      type: call.type
      method: call.method
      dataType: 'binary'
      headers: {'X-Auth-Token': window.authToken}
      success: (result, textStatus, jqXHR) ->
        if(result != "inProgress")
          callUrl = jsRoutes.controllers.gmql.DSManager.downloadFileZip window.lastDownloadDataSet
          window.location = callUrl.url
          dialog.close()
        else
          BootstrapDialog.alert "Download preparation is still in preparation"
          dialog.close()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("error222" + textStatus)


#    call = jsRoutes.controllers.gmql.DSManager.downloadFileZip window.lastSelectedDataSet
#    # always open windows for downloading
#    if false #window.URL
#      $.ajax
#        url: call.url
#        type: call.type
#        method: call.method
#        dataType: 'binary'
#        headers: {'X-Auth-Token': window.authToken}
#        success: (result, textStatus, jqXHR) ->
#          downloadResult(result, jqXHR)
#        error: (jqXHR, textStatus, errorThrown) ->
#          console.log("error222" + textStatus)
#  #      BootstrapDialog.alert "Error"
#    else


# expand the tree
$ ->
  setTimeout expandPublic, 1000
  setTimeout selectFirstPublic, 3000

expandPublic = ->
  $("#tree").fancytree("getRootNode").children[1].setExpanded(true)

selectFirstPublic = ->
  firstDS = $("#tree").fancytree("getRootNode").children[1].children[0]
  firstDS.setActive(true)

loadUcsc = ->
  newWin = window.open('', '_blank');
  newWin.blur();
  dataSet = window.lastSelectedDataSet
  console.log(".clicked")
  call = jsRoutes.controllers.gmql.DSManager.getUcscLink dataSet
  $.ajax
    url: call.url
    type: call.type
    method: call.method
    headers: {'X-Auth-Token': window.authToken}
    success: (result, textStatus, jqXHR) ->
      console.log result
      #      window.open (ucscBaseLink + result)
      newWin.location = ucscBaseLink + result
    error: (jqXHR, textStatus, errorThrown) ->
      BootstrapDialog.alert
        message: "Cannot prepare UCSC links for data set #{dataSet}"
        type: BootstrapDialog.TYPE_WARNING
      newWin.close()


