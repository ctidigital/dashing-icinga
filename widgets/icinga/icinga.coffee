class Dashing.Icinga extends Dashing.Widget
  ready: ->


  onData: (data) ->
    node = $(@node)
    node.removeClass('icinga-warning')
    node.removeClass('icinga-critical')
    node.addClass('icinga-ok')
    if data.services
      if data.services.WARNING.value
        console.log('services Warning')
        node.removeClass('icinga-ok')
        node.removeClass('icinga-critical')
        node.addClass('icinga-warning')
      if data.services.CRITICAL.value
        console.log('services Critial')
        node.removeClass('icinga-ok')
        node.removeClass('icinga-warning')
        node.addClass('icinga-critical')
    if data.hosts
      if data.hosts.UNREACHABLE.value
        node.removeClass('icinga-ok')
        node.removeClass('icinga-critical')
        node.addClass('icinga-warning')
      if data.hosts.DOWN.value
        node.removeClass('icinga-ok')
        node.removeClass('icinga-warning')
        node.addClass('icinga-critical')

