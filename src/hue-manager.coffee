_              = require 'lodash'
HueUtil        = require 'hue-util'
{EventEmitter} = require 'events'

class HueManager extends EventEmitter
  connect: ({ @options, @apikey, desiredState }, callback) =>
    @_emit = _.throttle @emit, 500, {leading: true, trailing: false}
    @apikey ?= {}
    @options ?= {}

    {ipAddress, @lightNumber} = @options
    {username} = @apikey

    @apikey.devicetype = devicetype = 'octoblu-hue-light'
    @hue = new HueUtil devicetype, ipAddress, username, @_onUsernameChange

    @stateInterval = setInterval @_updateState, 30000
    @verify (error) =>
      return callback error if error?
      @changeLight desiredState, callback

  verify: (callback) =>
    @hue.verify callback

  close: (callback) =>
    clearInterval @stateInterval
    delete @stateInterval
    callback()

  _onUsernameChange: (username) =>
    return if username == @apikey.username
    @apikey.username = username
    @_emit 'change:username', {@apikey}

  _updateState: (update={}, callback) =>
    callback ?= (error) =>
      @emit 'error', error if error?

    @getLight (error, light) =>
      return callback error if error?
      deviceUpdate = _.pick light, ['color', 'alert', 'effect', 'on']
      update = _.merge update, deviceUpdate
      @_emit 'update', update
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
      @_updateState desiredState: null, callback

module.exports = HueManager
