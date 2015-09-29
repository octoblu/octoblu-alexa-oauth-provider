cors          = require 'cors'
morgan        = require 'morgan'
express       = require 'express'
bodyParser    = require 'body-parser'
OAuth2Server  = require 'oauth2-server'
OctobluOauth  = require './oauth'
MeshbluConfig = require 'meshblu-config'
AuthCodeGrant = require './authCodeGrant'

meshbluConfig      = new MeshbluConfig().toJSON()
meshbluHealthcheck = require 'express-meshblu-healthcheck'

OCTOBLU_BASE_URL = process.env.OCTOBLU_BASE_URL ? 'https://app.octoblu.com'
REDIRECT_URI     = process.env.REDIRECT_URI

return console.error "Missing Redirect URI" unless REDIRECT_URI?

PORT = process.env.PORT ? 80

OAuth2Server.prototype.authCodeGrant = (check) ->
  that = @
  (req, res, next) =>
    new AuthCodeGrant that, req, res, next, check

app = express()
app.use cors()
app.use morgan('combined')
app.use bodyParser.urlencoded extended: true
app.use bodyParser.json()
app.use meshbluHealthcheck()

app.oauth = OAuth2Server
  model: new OctobluOauth meshbluConfig
  grants: [ 'authorization_code', 'client_credentials' ]
  debug: true

app.all '/access_token', app.oauth.grant()

app.get '/authorize', (req, res) ->
  redirectUri = "#{OCTOBLU_BASE_URL}/oauth/#{req.query.client_id}?redirect=#{encodeURIComponent("/auth_code")}&redirect_uri=#{encodeURIComponent(REDIRECT_URI)}&response_type=#{encodeURIComponent(req.query.response_type)}"
  res.redirect encodeURIComponent redirectUri

app.get '/auth_code', app.oauth.authCodeGrant (req, next) =>
  next null, true, req.params.uuid, null

app.use app.oauth.errorHandler()

app.listen PORT
