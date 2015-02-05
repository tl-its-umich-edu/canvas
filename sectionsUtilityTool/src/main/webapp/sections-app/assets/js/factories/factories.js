'use strict';
/* global  sectionsApp, errorHandler  */

//COURSES FACTORY - does the request for the courses controller
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
//SECTIONS FACTORY - does the request for the sections controller
sectionsApp.factory('Sections', function ($http) {
  return {
    getSectionsForCourseId: function (courseId, uniqname) {
      //TODO: needs changing to the servlet endpoint
      var url = '../../section_data/sections-' + uniqname + '-' + courseId + '.json';
      return $http.get(url, {cache: true}).then(
        function success(result) {
          return result;
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

