/*
 *
 * Copyright Daniel Hutmacher under Creative Commons 4.0 license with attribution.
 * http://creativecommons.org/licenses/by/4.0/
 *
 * Source: https://github.com/sqlsunday/sp_ctrl3
 *
 * DISCLAIMER: This script may not be suitable to run in a production
 *            environment. I cannot assume any responsibility regarding
 *            the accuracy of the output information, performance
 *            impacts on your server, or any other consequence. If
 *            your juristiction does not allow for this kind of
 *            waiver/disclaimer, or if you do not accept these terms,
 *            you are NOT allowed to store, distribute or use this
 *            code in any way.
 *
 * This is a rework of my original "canned SQL" abstraction layer that I
 * made some time ago because I got so tired or juggling the asynchronous
 * nightmare that was querying SQL Server with Tedious, not to mention
 * getting the error handling to do what I wanted.
 *
 * This module depends on the "tedious" Node.js module.
 *
 * A significant part of the code in this module was written with AI
 * assistance, although I've reviewed, tested, commented, and cleaned the
 * result manually.
 *
 */


const Connection = require('tedious').Connection;
const Request = require('tedious').Request;  
const TYPES = require('tedious').TYPES;
const ISOLATION_LEVEL = require('tedious').ISOLATION_LEVEL;






// Create the database connection:

async function connect(config) {
    const connection = new Connection(config);
    
    await new Promise((resolve, reject) => {
        connection.connect((err) => {
            if (err) reject(err);
            resolve();
        });
    });
  
    return connection;
}
  
  
  
// Run the SQL batch:

async function query(connection, statement, parameters) {
    return new Promise((resolve, reject) => {
        const resultSets = [];
        let currentResultSet = [];
        let errorRaised = false;

        const request = new Request(statement, (err) => {
            if (err) {
                errorRaised = true;

                // In some cases, we get an array of errors[]. Other times, we get
                // a single error object (and no message). Tedious moves in mysterious
                // ways. *sigh*

                if (err.errors) {
                    resolve({
                        success: false,
                        error: {
                            message: err.errors[0].message,
                            code: err.errors[0].code,
                            state: err.errors[0].state,
                            class: err.errors[0].class,
                            lineNumber: err.errors[0].lineNumber,
                            serverName: err.errors[0].serverName
                        }
                    });
                }
                else
                {
                    resolve({
                        success: false,
                        error: {
                            message: err.message,
                            code: err.code,
                            state: err.state,
                            class: err.class,
                            lineNumber: err.lineNumber,
                            serverName: err.serverName
                        }
                    });
                }
            }
        });

        // If the user provided parameters, we'll add those now:
        if (parameters) {
            parameters.forEach(function(parameter) {
                request.addParameter(parameter.name, parameter.type, parameter.value);
            });
        }

        // When a row arrives, add all the column values to a row object, add that row object to currentResultSet:
        request.on('row', (columns) => {
            const row = {};
            for (const column of columns) {
                row[column.metadata.colName] = column.value;
            }
            currentResultSet.push(row);
        });

        // At the end of a resultset, add it to resultSets, and start over:
        request.on('doneInProc', (rowCount, more) => {
            if (currentResultSet.length > 0) {
                resultSets.push([...currentResultSet]);
                currentResultSet = [];
            }
        });

        // When the request completes, add the last result set to resultSets:
        request.on('requestCompleted', () => {
            // Handle any remaining rows in the current set
            if (currentResultSet.length > 0) {
                resultSets.push([...currentResultSet]);
            }

            if (!errorRaised) {
                // Resolve: return success and the resultSets array:
                resolve({
                    success: true,
                    results: resultSets
                });
            }
        });

        // If something went wrong:
        request.on('error', (error) => {
            errorRaised = true;

            // We'll still resolve the Promise, in order to not trigger any errors,
            // but we'll set success:false, and include a description of the error.
            resolve({
                success: false,
                error: {
                    message: error.message,
                    code: error.code,
                    state: error.state,
                    class: error.class,
                    lineNumber: error.lineNumber,
                    serverName: error.serverName
                }
            });
        });

        // With all that set up, we're ready to fire off the request:
        connection.execSql(request);
    });
};




// BEGIN TRANSACTION:

const beginTransaction = (connection, isolationLevel) => {
    return new Promise((resolve, reject) => {
        connection.beginTransaction((err) => {
            if (err) {
                resolve({
                    success: false,
                    error: {
                        message: err.message,
                        code: err.code,
                        state: err.state,
                        class: err.class,
                        lineNumber: err.lineNumber,
                        serverName: err.serverName
                    }
                });
            } else {
                resolve({ success: true });
            }
        }, '', isolationLevel || 0);
    });
};

// COMMIT TRANSACTION:

const commitTransaction = (connection) => {
    return new Promise((resolve, reject) => {
        connection.commitTransaction((err) => {
            if (err) {
                resolve({
                    success: false,
                    error: {
                        message: err.message,
                        code: err.code,
                        state: err.state,
                        class: err.class,
                        lineNumber: err.lineNumber,
                        serverName: err.serverName
                    }
                });
            } else {
                resolve({ success: true });
            }
        });
    });
};

// ROLLBACK TRANSACTION:

const rollbackTransaction = (connection) => {
    return new Promise((resolve, reject) => {
        connection.rollbackTransaction((err) => {
            if (err) {
                resolve({
                    success: false,
                    error: {
                        message: err.message,
                        code: err.code,
                        state: err.state,
                        class: err.class,
                        lineNumber: err.lineNumber,
                        serverName: err.serverName
                    }
                });
            } else {
                resolve({ success: true });
            }
        });
    });
};









// Export the functions

exports.query = query;
exports.connect = connect;
exports.begin = beginTransaction;
exports.commit = commitTransaction;
exports.rollback = rollbackTransaction;



// Isolation levels
exports.READ_UNCOMMITTED = ISOLATION_LEVEL.READ_UNCOMMITTED;
exports.READ_COMMITTED = ISOLATION_LEVEL.READ_COMMITTED;
exports.REPEATABLE_READ = ISOLATION_LEVEL.REPEATABLE_READ;
exports.SERIALIZABLE = ISOLATION_LEVEL.SERIALIZABLE;
exports.SNAPSHOT = ISOLATION_LEVEL.SNAPSHOT;




// Translating SQL Server datatypes to their respective types in Tedious.
// This is how the user defines the data types in parameterized queries.

exports.bit = TYPES.Bit;
exports.tinyint = TYPES.TinyInt;
exports.smallint = TYPES.SmallInt;
exports.int = TYPES.Int;
exports.bigint = TYPES.BigInt; // Warning: values are returned as a string because bigint can exceed 53 bits in length
exports.numeric = TYPES.Numeric; // Max precision supported for input paramters is currently 19
exports.decimal = TYPES.Decimal; // Max precision supported for input paramters is currently 19
exports.smallmoney = TYPES.SmallMoney;
exports.money = TYPES.Money;

exports.float = TYPES.Float;
exports.real = TYPES.Real;

exports.smalldatetime = TYPES.SmallDateTime;
exports.datetime = TYPES.DateTime;
exports.datetime2 = TYPES.DateTime2;
exports.datetimeoffset = TYPES.DateTimeOffset;
exports.time = TYPES.Time;
exports.date = TYPES.Date;

exports.char = TYPES.Char;
exports.varchar = TYPES.VarChar;
exports.text = TYPES.Text;

exports.nchar = TYPES.NChar;
exports.nvarchar = TYPES.NVarChar;
exports.ntext = TYPES.NText;

exports.binary = TYPES.Binary;
exports.varbinary = TYPES.VarBinary;
exports.image = TYPES.Image;

exports.uniqueidentifier = TYPES.UniqueIdentifier; // Returned as hexadecimal string
exports.sql_variant = TYPES.Variant;
exports.xml = TYPES.Xml;

