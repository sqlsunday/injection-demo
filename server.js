#!/usr/bin/env node



// Other modules:
const express = require('express');
const cookieSession = require('cookie-session');

// HTTP port that the server will run on:
var serverPort=process.argv[2] || process.env.PORT || 3000;

// The web server:
const app = express();
app.disable('etag');
app.disable('x-powered-by');
app.enable('trust proxy');

app.use(express.json( { limit: '10mb' }));
app.use(express.urlencoded( { limit: '10mb', extended: true }));

app.use(cookieSession({
    name: 'session',
    secret: (process.env.cookieSecret || 'dev'),
    rolling: true,
    secure: !(serverPort==3000),            // on dev environment only, allow cookies even without HTTPS.
    sameSite: true,
    resave: true,
    maxAge: 60 * 60 * 1000                  // 1 hour login cookie life
}));

// Here are our web routes:
const webRoutes=require('./webserver-routes.js');










/*-----------------------------------------------------------------------------
  Start the web server
-----------------------------------------------------------------------------*/

console.log('HTTP port:       '+serverPort);
console.log('Database server: '+process.env.dbserver);
console.log('Express env:     '+app.settings.env);
console.log('');

app.listen(serverPort, () => console.log('READY.'));





/*-----------------------------------------------------------------------------
  Add routes
-----------------------------------------------------------------------------*/



// There's no place like /.
app.get('/', webRoutes.home);

// Azure Linux App Service Plan health check request:
app.get('/robots933456.txt', webRoutes.linuxHealthCheck);

// Login page
app.get('/login', webRoutes.login);
app.post('/login', webRoutes.doLogin);

// Log out
app.all('/logout', webRoutes.doLogout);

// Dashboard page
app.get('/dashboard', webRoutes.dashboard);

// Other related assets, like CSS or other files:
app.get('/assets/:asset', webRoutes.asset);



