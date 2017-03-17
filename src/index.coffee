{EventEmitter}  = require 'events'
debug           = require('debug')('meshblu-connector-hue-light-and-button:index')
HueManager      = require './hue-manager'

class Connector extends EventEmitter
  constructor: ->
    @hue = new HueManager
    @hue.on 'error', (error)              => @emit 'error', error
    @hue.on 'change:username', ({apikey}) => @emit 'update', {apikey}
    @hue.on 'click', @_onClick
    @hue.on 'update', (data)              => @emit 'update', data

  isOnline: (callback) =>
    callback null, running: true

  close: (callback) =>
    debug 'on close'
    @hue.close callback

  onConfig: (@device={}, callback=->) =>
    { options, apikey, desiredState } = @device
    debug 'on config', options
    @hue.close (error) =>
      return callback error if error?
      @hue.connect {options, apikey, desiredState}, (error) =>
        return callback error if error?
        @connected = true
        callback()

  start: (device, callback) =>
    debug 'started'
    @onConfig device, callback

  _onClick: ({button, state}) =>
    data = {
      action: 'click'
      button
      state
      @device
    }
    @emit 'message', {devices: ['*'], data}

module.exports = Connector
