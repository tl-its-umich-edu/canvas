'use strict';
/* jshint  strict: true*/
/* global $, angular */

var sectionsApp = angular.module('sectionsApp', ['sectionsFilters']);

sectionsApp.run(function ($rootScope) {
  $rootScope.user = $.trim($('#uniqname').val());
});

sectionsApp.controller('coursesController', ['Courses', 'Sections', '$rootScope', '$scope', function (Courses, Sections, $rootScope, $scope) {
  $scope.courses = [];
  $scope.loading = true;

 $scope.getCoursesForUniqname = function () {
    var uniqname = $.trim($('#uniqname').val());
    $scope.uniqname = uniqname;
    var url = '../../../section_data/courses-' + uniqname + '.json';
    Courses.getCourses(url).then(function (data) {
      if (data.failure) {
        if(uniqname) {
          $scope.errorMessage = 'Could not get data for uniqname \"' + uniqname + '\"';
        }
        else {
          $scope.errorMessage = 'Please supply a uniqname at left';
        }
        $scope.success = false;
        $scope.error = true;
      } else {
        $scope.courses = data.data;
        $scope.error = false;
        $scope.success = true;
        $scope.successMessage = 'Found ' + data.data.length + ' courses for ' + uniqname;
      }
    });
  };
      $scope.getSections = function (courseId, uniqname) {
        Sections.getSectionsForCourseId(courseId, uniqname).then(function (data) {
          if (data) {
            //need to find what node of the scope is the one to add things to (underscore)
            //var pos = 0;
            //$scope.courses[pos].push();
          } else {
            //deal with this
          }
        });
    };
}]);


sectionsApp.controller('termsController', ['Courses', '$rootScope', '$scope', '$http', function (Courses, $rootScope, $scope, $http) {
  $scope.selectedTerm = null;
  $scope.terms = [];
 
  var termsUrl = 'terms';

  $http.get(termsUrl).success(function (data) {
    $scope.terms = data;
    $scope.$parent.term = data[0].term;
    $scope.$parent.year = data[0].year;
  });

  $scope.getTerm = function (termId, term, year) {
    $scope.$parent.loading = true;
    $scope.$parent.courses = [];
    $scope.$parent.term = term;
    $scope.$parent.year = year;
    var url = 'courses/' + $rootScope.user + '.json'+ '?TERMID='+termId;

    Courses.getCourses(url).then(function (data) {
      if (data.failure) {
        $scope.$parent.courses.errors = data;
        $scope.$parent.loading = false;
      } else {
          $scope.$parent.courses = data;
          $scope.$parent.loading = false;
      }
    });

  };

}]);
