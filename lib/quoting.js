export const escape = function(val) {
  return val.toString().replace(/'/g, "''");
};

export const quote = function(val) {
  var v;
  if (val == null) {
    return 'NULL';
  } else if (typeof val.sqlQuoted === 'function') {
    return val.sqlQuoted();
  } else if (val === true) {
    return 'TRUE';
  } else if (val === false) {
    return 'FALSE';
  } else if (typeof val === 'number') {
    return val.toString();
  } else if (typeof val === 'string') {
    return "'" + (exports.escape(val)) + "'";
  } else if (val instanceof Array) {
    return ((function() {
      var i, len, results;
      results = [];
      for (i = 0, len = val.length; i < len; i++) {
        v = val[i];
        results.push(exports.quote(v));
      }
      return results;
    })()).join(', ');
  } else if (val instanceof Date) {
    return "'" + (val.toISOString().replace(/T/, ' ').replace(/\.\d+Z$/, '')) + "'::timestamp";
  } else {
    return "'" + (exports.escape(val)) + "'";
  }
};

export const quoteIdentifier = function(val) {
  return '"' + val.toString().replace(/"/g, '""') + '"';
};
