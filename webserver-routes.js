// Core modules:
const fs = require('fs');
const path = require('path');

// Import the "canned SQL" module, which we'll use to run SQL Server queries:
const cannedSql=require('./canned-sql2.js');

// Configure the connection:
const config = {
server: process.env.dbserver,               // Environment variable: database server
    authentication: {
        type: 'default',
        options: {
            userName: process.env.dblogin,  // Environment variable: database login
            password: process.env.dbpasswd  // Environment variable: database password
        }
    },
    options: {
        port: parseInt(process.env.dbport || 1433),   // Environment variable: port number to connect to
        database: process.env.dbname,       // Environment variable: database name
        trustServerCertificate: true
    }
};







/*-----------------------------------------------------------------------------
  Azure Linux App Service Plan health check request:
  ---------------------------------------------------------------------------*/

exports.linuxHealthCheck = function (req, res, next) {
    console.log("Azure health check: OK.");
    res.status(200).send("OK");
}




/*-----------------------------------------------------------------------------
  Other related assets, like CSS or other files:
  ---------------------------------------------------------------------------*/

exports.asset = function (req, res, next) {

    httpHeaders(res);

    var options = {
        maxAge: 60 * 60 * 1000,         // Cache static files like stylesheets, client-side scripts, etc for up to 1 hour
        root: __dirname + '/assets/',
        dotfiles: 'deny',
        headers: {
            'x-timestamp': Date.now(),
            'x-sent': true
        }
    };

    res.sendFile(req.params.asset, options, function(err) {
        if (err) {
            res.sendStatus(404);
            return;
        }
    });
}



/*-----------------------------------------------------------------------------
  Default URL:
  ---------------------------------------------------------------------------*/

exports.home = function (req, res, next) {

    if (!req.session.userName) {
        res.redirect("/login");
    } else {
        res.redirect("/dashboard");
    }

}




/*-----------------------------------------------------------------------------
  Login page:
  ---------------------------------------------------------------------------*/

exports.login = function (req, res, next) {
    if (req.session.userName) {
        res.redirect("/dashboard");
        return;
    }

    httpHeaders(res);
    res.status(200).send(createHTML("assets/login.html"));
}

exports.doLogin = async function (req, res, next) {

    // Create the connection
    const conn=await cannedSql.connect(config);

    // BAD PRACTICE: This query is not parameterized, making it vulnerable to SQL injection.
    const query="SELECT UserName FROM dbo.SalesAgents WHERE UserName='"+req.body.username+"' AND PasswordText='"+req.body.password+"';"
    console.log(query);

    // Run the query
    const queryResults=await cannedSql.query(conn, query);
    console.log(queryResults);


    // BAD PRACTICE: Displaying error messages to the client can help bad actors.
    if (!queryResults.success) {
        res.status(403).send(queryResults.error.message);
        return;
    }


    if (queryResults.success) {

        // Was a resultset returned?
        if (queryResults.results.length>0) {

            // Does the resultset have a row?
            if (queryResults.results[0].length>0) {

                // Set the auth cookie and go to dashboard:
                req.session.userName=queryResults.results[0][0].UserName;
                res.redirect("/dashboard");
                return;
            }
        }
    }


    // Back to the login page
    res.redirect("/login");

}





/*-----------------------------------------------------------------------------
  Logout:
  ---------------------------------------------------------------------------*/

exports.doLogout = function (req, res, next) {
    req.session.userName=undefined;
    res.redirect("/login");
    return;
}





/*-----------------------------------------------------------------------------
  Dashboard:
  ---------------------------------------------------------------------------*/

exports.dashboard = async function (req, res, next) {
    if (!req.session.userName) {
        res.redirect("/login");
    }

    httpHeaders(res);

    // Create the connection
    const conn=await cannedSql.connect(config);

    // Run the dashboard query
    const queryResults=await cannedSql.query(conn, "SELECT * FROM dbo.SalesDashboard WHERE UserName=@UserName AND SYSDATETIME() BETWEEN From_Date AND To_Date;" +
                                                   "SELECT s.[Timestamp], p.ProductName, s.Quantity, s.UnitPrice FROM dbo.Sales AS s INNER JOIN dbo.Products AS p ON s.ProductId=p.Id WHERE s.SalesAgentId=(SELECT Id FROM dbo.SalesAgents WHERE UserName=@UserName) ORDER BY [Timestamp] DESC;",
            [{ "name": "UserName", "type": cannedSql.nvarchar, "value": req.session.userName }]);

    if(queryResults.success) {

        let metrics = queryResults.results[0][0];
        let salesDetailsHTML = "";

        for(row of queryResults.results[1]) {
            salesDetailsHTML += "<tr> \
            <td>"+(new Date(row.Timestamp)).toISOString().substring(0, 10)+"</td> \
            <td>"+simpleHtmlEncode(row.ProductName)+"</td> \
            <td class=\"number\">"+row.Quantity.toFixed(1)+"</td> \
            <td class=\"number\">"+row.UnitPrice.toFixed(2)+"</td> \
            </tr>"
        }
console.log(metrics);
        httpHeaders(res);
        res.status(200).send(createHTML("assets/dashboard.html",
            {
                "Year": (new Date(metrics.From_Date)).getFullYear(),
                "PrevYear": (new Date(metrics.From_Date)).getFullYear()-1,
                "Sales": (metrics.Sales || 0).toFixed(2),
                "PrevSales": (metrics.Sales_prev_year || 0).toFixed(2),
                "SalesTarget": metrics.TargetAmount.toFixed(2),
                "Discount": metrics.DiscountPercent.toFixed(2)+"%",
                "SalesTargetCss": ((metrics.Sales || 0) < 0.9 * metrics.SalesTarget ? "red" : ((metrics.Sales || 0) >= metrics.TargetAmount ? " green" : " orange")),
                "SalesDetails": salesDetailsHTML
            }
        ));

        return;
    }

    httpHeaders(res);
    res.status(500).send("There was a problem loading the dashboard.");
}







/*-----------------------------------------------------------------------------
  Format an HTML template:
  ---------------------------------------------------------------------------*/

function createHTML(templateFile, values) {
    var rn=Math.random();

    // Read the template file:
    var htmlTemplate = fs.readFileSync(path.resolve(__dirname, './'+templateFile), 'utf8').toString();

    // Loop through the JSON blob given as the argument to this function,
    // replace all occurrences of <%=param%> in the template with their
    // respective values.
    for (var param in values) {
        if (values.hasOwnProperty(param)) {
            htmlTemplate = htmlTemplate.split('\<\%\='+param+'\%\>').join(values[param]);
        }
    }

    // Special parameter that contains a random number (for caching reasons):
    htmlTemplate = htmlTemplate.split('\<\%\=rand\%\>').join(rn);
    
    // Clean up any remaining parameters in the template
    // that we haven't replaced with values from the JSON argument:
    while (htmlTemplate.includes('<%=')) {
        param=htmlTemplate.substr(htmlTemplate.indexOf('<%='), 100);
        param=param.substr(0, param.indexOf('%>')+2);
        htmlTemplate = htmlTemplate.split(param).join('');
    }

    // DONE.
    return(htmlTemplate);
}


/*-----------------------------------------------------------------------------
  Primitive HTML encoding:
  ---------------------------------------------------------------------------*/

function simpleHtmlEncode(plaintext) {
    var html=plaintext;
    html=html.replace('&', '&amp;');
    html=html.replace('<', '&lt;');
    html=html.replace('>', '&gt;');
    return(html);
}






/*-----------------------------------------------------------------------------
  Set a bunch of standard HTTP headers:
  ---------------------------------------------------------------------------*/

function httpHeaders(res) {

    // Don't allow this site to be embedded in a frame; helps mitigate clickjacking attacks
    res.header('X-Frame-Options', 'sameorigin');

    // Prevent MIME sniffing; instruct client to use the declared content type
    res.header('X-Content-Type-Options', 'nosniff');

    // Don't send a referrer to a linked page, to avoid transmitting sensitive information
    res.header('Referrer-Policy', 'no-referrer');

    // Limit access to local devices
    res.header('Permissions-Policy', "camera=(), display-capture=(), microphone=(), geolocation=(), usb=()"); // replaces Feature-Policy

    return;
}

