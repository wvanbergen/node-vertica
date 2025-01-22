
import { Connection } from './connection.js';
import { Resultset } from './resultset.js';
import { Date, Time, Timestamp, Interval } from './types.js';
import { escape, quote, quoteIdentifier } from './quoting.js';

export {
  Connection,
  Resultset,
  Date,
  Time,
  Timestamp,
  Interval,
  escape,
  quote,
  quoteIdentifier
}

export const connect = function(connectionOptions, callback) {
  var connection;
  connection = new Connection(connectionOptions);
  connection.connect(callback);
  return connection;
}

export const setTimezoneOffset = Timestamp.setTimezoneOffset;
