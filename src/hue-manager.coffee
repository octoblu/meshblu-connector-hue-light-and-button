async          = require 'async'
_              = require 'lodash'
HueUtil        = require 'hue-util'
{EventEmitter} = require 'events'

class HueManager extends EventEmitter
  connect: ({ @options, @apikey, desiredState }, callback) =>
    @_emit = _.throttle @emit, 500, {leading: true, trailing: false}
    @apikey ?= {}
    @options ?= {}

    {@lightNumber, @lightPollInterval} = @options
    {@sensorName, @sensorPollInterval} = @options

    @apikey.devicetype = 'octoblu-hue-light-and-button'
    @hue = new HueUtil @apikey.devicetype, @options.ipAddress, @apikey.username, @_onUsernameChange

    @verify (error) =>
      return callback error if error?
      async.parallel [
        @_setInitialState
        async.apply @changeLight, desiredState
      ], (error) =>
        return callback error if error?
        @_createPollInterval()
        callback()

  changeLight: (data, callback) =>
    return callback() if _.isEmpty data
    {
      color
      transitionTime
      alert
      effect
    } = data

    @hue.changeLights { @lightNumber, color, transitionTime, alert, effect, on: data.on }, (error) =>
      return callback error if error?
      @_updateLight desiredState: null, callback

  close: (callback) =>
    clearInterval @stateInterval
    delete @stateInterval
    callback()

  getLight: (callback) =>
    @hue.getLight @lightNumber, (error, light) =>
      return callback error if error?
      { bri, sat, hue, alert, effect } = light.state

      return callback null, {
        color: @hue.toTinycolor({ bri, sat, hue }).toHex8String()
        alert: alert
        effect: effect
        on: light.state.on
      }

  verify: (callback) =>
    @hue.verify callback

  _checkButtons: (callback) =>
    @hue.checkButtons @sensorName, (error, result) =>
      return callback error if error?
      callback null, result

  _createPollInterval: =>
    clearInterval @pollInterval
    clearInterval @stateInterval

    @pollInterval  = setInterval @_updateSensor, @sensorPollInterval if @sensorPollInterval?
    @stateInterval = setInterval @_updateLight,  @lightPollInterval  if @lightPollInterval?

  _onUsernameChange: (username) =>
    return if username == @apikey.username
    @apikey.username = username
    @_emit 'change:username', {@apikey}

  _updateLight: (update={}, callback) =>
    callback ?= (error) =>
      @emit 'error', error if error?

    @getLight (error, light) =>
      return callback error if error?
      deviceUpdate = _.pick light, ['color', 'alert', 'effect', 'on']
      update = _.merge update, deviceUpdate
      return callback() if _.isEqual update, @previousLightUpdate
      @previousLightUpdate = update
      @_emit 'update', update
      callback()

  _updateSensor: (callback) =>
    callback ?= (error) =>
      @emit 'error', error if error?

    @_checkButtons (error, result) =>
      return callback error if error?
      {state, button} = result ? {}
      return callback() if _.isEqual result, @previousSensorResult
      @previousSensorResult = result
      @_emit 'click', {button, state}

module.exports = HueManager
