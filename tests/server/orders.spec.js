(function () {
  "use strict";
  var rewire = require("rewire");
  var assert = require("chai").assert;
  var sinon = require("sinon");

  var mockdb = {
    ordersDb: {
      insert: function (body, cb) {
        cb(null);
      },
      get: function (id, obj, cb) {
        cb(null, "body");
      }
    }
  };

  global.cloudantService = {
    credentials: {
      url: "https://abc"
    }
  };
  var orders = rewire(
    "../../tests/server/coverage/instrumented/routes/orders.js"
  );
  //orders.__set__('cloudant', mockcloudant);
  orders.__set__("ordersDb", mockdb.ordersDb);
  // create mock request and response
  var reqMock = {
    params: {
      option: "create"
    }
  };
  var resMock = {};
  resMock.status = function () {
    return this;
  };
  resMock.send = function () { };
  resMock.end = function () { };
  sinon.spy(resMock, "send");

  describe("create Function", function () {
    it("Order created successfully", function () {
      orders.create(reqMock, resMock);
      
      assert(
        resMock.send.lastCall.calledWith({ msg: "Successfully created order" }),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });

    it("Order not created - db error", function () {
      mockdb.ordersDb.insert = function (key, callback) {
        callback("forced error");
      };

      orders.create(reqMock, resMock);
      assert(
        resMock.send.lastCall.calledWith({
          msg: "Error on insert, maybe the order already exists: forced error"
        }),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });
  });

  describe("find Function", function () {
    it("Order found successfully", function () {
      reqMock.params.id = "testId";
      mockdb.ordersDb.get = function (id, arg, callback) {
        callback(false, "test body");
      };

      orders.find(reqMock, resMock);

      assert(
        resMock.send.lastCall.calledWith("test body"),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });

    it("Order not found - db error", function () {
      reqMock.params.id = "testId";
      mockdb.ordersDb.get = function (id, arg, callback) {
        callback("forced error", "");
      };

      orders.find(reqMock, resMock);

      assert(
        resMock.send.lastCall.calledWith({
          msg: "Error: could not find order: testId"
        }),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });
  });

  describe("list Function", function () {
    it("All Db content listed successfully", function () {
      mockdb.ordersDb.list = function (arg, callback) {
        callback(false, "No orders logged", "headers");
      };

      orders.list(reqMock, resMock);
      assert(
        resMock.send.lastCall.calledWith("No orders logged"),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });

    it("Db content not listed - db error", function () {
      mockdb.ordersDb.list = function (arg, callback) {
        callback("forced error", "test body", "headers");
      };

      orders.list(reqMock, resMock);
      assert(
        resMock.send.lastCall.calledWith({
          msg: "'list' failed: forced error"
        }),
        "Unexpected argument: " + JSON.stringify(resMock.send.lastCall.args)
      );
    });
  });
})();
