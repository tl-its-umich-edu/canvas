'use strict';
/* global  sectionsApp, errorDisplay  */

//COURSES FACTORY - does the request for the courses controller
sectionsApp.factory('Courses', function ($http) {
  return {
    getCourses: function (url) {
      return $http.get(url, {cache: false}).then(
        function success(result) {
          //forward the data - let the controller deal with it
          return result; 
        },
        function error(result) {
          errorDisplay(url, result.status, 'Unable to get courses');
          result.errors.failure = true;    
          return result;
        }
      );
    }
  };
});
//SECTIONS FACTORY - does the request for the sections controller
sectionsApp.factory('Sections', function ($http) {
  return {
    getSectionsForCourseId: function (courseId) {
      //TODO: needs changing to the servlet endpoint
    	//var mini="/sectionsUtilityTool/manager/api/v1/courses/656/sections?per_page=100"
      var url = '/sectionsUtilityTool/manager/api/v1/courses/' + courseId + '/sections?per_page=100';
      return $http.get(url, {cache: false}).then(
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

