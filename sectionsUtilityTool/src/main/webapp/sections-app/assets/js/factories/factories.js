sectionsApp.factory('Courses', function ($http) {
  return {
    getCourses: function (url) {
      return $http.get(url, {cache: true}).then(
        function success(result) {
            return result;
        },
        function error(result) {
          result.errors = errorHandler(url, result);
          result.errors.failure = true;
          return result.errors;
        }
      );
    }
  };
});

sectionsApp.factory('someFactory', function ($http) {
  return {
    someMethod: function (building) {
      var url = 'data/buildings/' + _.last(building.split(' ')).toLowerCase() + '.json';
      return $http.get(url, {cache: true}).then(
        function success(result) {
          var coords = {};
          coords.latitude = result.data.Buildings.Building.Latitude;
          coords.longitude = result.data.Buildings.Building.Longitude;
          return coords;
        },
        function error() {
          //do something in case of error
          //result.errors.failure = true;
          //return result.errors;
        }
      );
    }
  };
});


sectionsApp.factory('pageDay', function () {
  return {
      getDay: function (wdayintnew) {
        //wdayintnew=4; // for testing
        var weekday=new Array(7);
        weekday[1]=['Mo', 'Monday'];
        weekday[2]=['Tu', 'Tuesday'];
        weekday[3]=['We', 'Wednesday'];
        weekday[4]=['Th', 'Thursday'];
        weekday[5]=['Fr', 'Friday'];
        weekday[6]=['Sa', 'Saturday'];
        weekday[7]=['Su', 'Sunday'];
        return  weekday[wdayintnew];
      }
  };
});
