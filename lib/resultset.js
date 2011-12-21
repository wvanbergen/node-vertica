(function() {
  var Resultset;

  Resultset = (function() {

    function Resultset(object) {
      this.fields = object.fields || [];
      this.rows = object.rows || [];
      this.notices = object.notices || [];
      this.status = object.status;
    }

    Resultset.prototype.theValue = function() {
      return this.rows[0][0];
    };

    return Resultset;

  })();

  module.exports = Resultset;

}).call(this);
