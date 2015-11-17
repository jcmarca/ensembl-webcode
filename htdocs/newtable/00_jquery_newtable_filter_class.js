/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

(function($) {
  function update_counts($el,state,values) {
    var m = 0;
    var n = 0;
    $.each(values,function(i,val) {
      n++;
      if(!state[val]) { m++; }
    });
    $el.text('('+m+'/'+n+' on)');
  }

  function add_baked($baked,$body,$el,$summary,values,key,km) {
    var all = [];
    var $allon = $('<li/>').addClass('allon').addClass('allonoff').text('All On');
    all.push($allon);
    $allon.click(function() {
      state = {};
      $body.children('ul').children('li').addClass('on');
      $el.trigger('update',state);
      update_counts($summary,state,values);
    });
    var bakery = ((km['*']||{}).bakery)||[];
    for(var i=0;i<bakery.length;i++) {
      var $bake = $('<li/>').addClass('allonoff').addClass('alloff').text(bakery[i].label);
      all.push($bake);
    }

    var $alloff = $('<li/>').addClass('allonoff').addClass('alloff').text('All Off');
    $alloff.click(function() {
      state = {};
      $body.children('ul').children('li').removeClass('on').each(function() {
        state[$(this).data('key')] = 1;
      });
      $el.trigger('update',state);
      update_counts($summary,state,values);
    });
    all.push($alloff);
    var $buttons = $('<ul/>').addClass('bakery').appendTo($baked);
    all[0].addClass('first');
    all[all.length-1].addClass('last');
    if(all.length>2) { all[all.length-1].addClass('last_of_many'); }
    for(var i=0;i<all.length;i++) { $buttons.append(all[i]); }
  }

  $.fn.newtable_filter_class = function(config,data) {
    return {
      filters: [{
        name: "class",
        display: function($box,$el,values,state,km,key,$table) {
          var cc = config.colconf[key];
          var title = (cc.filter_label || cc.label || cc.title || key);
          var $summary = $('.summary',$box).text('(x/y on)');
          var $baked = $('<div class="baked"/>').appendTo($box);
          var $body = $('<div class="body"/>').appendTo($box);
          add_baked($baked,$body,$el,$summary,values,key,km);
          values = values.slice();
          if(!cc.filter_sorted) {
            values.sort(function(a,b) { return a.localeCompare(b); });
          }
          var $ul;
          var splits = [0];
          if(values.length > 4) {
            splits = [0,values.length/3,2*values.length/3];
            $body.addClass('use_cols');
          }
          $.each(values,function(i,val) {
            if(i>=splits[0]) {
              $ul = $("<ul/>").appendTo($body);
              splits.shift();
            }
            if(i===0 && 0) {
              var $allon = $('<div/>').addClass('allon').text('All On');
              $allon.click(function() {
                state = {};
                $body.children('ul').children('li').addClass('on');
                $el.trigger('update',state);
              });
              var $alloff = $('<div/>').addClass('alloff').text('All Off');
              $alloff.click(function() {
                state = {};
                $body.children('ul').children('li').removeClass('on').each(function() {
                  state[$(this).data('key')] = 1;
                });
                $el.trigger('update',state);
              });
              $('<li/>').addClass('allonoff').append($allon).append($alloff).appendTo($ul);
            }
            var $li = $("<li/>").data('key',val).appendTo($ul);
            $table.trigger('paint-individual',[$li,key,val]);
            $li.data('val',val);
            if(!state[val]) { $li.addClass("on"); }
            $li.on('click',function() {
              $(this).toggleClass('on');
              if(state[val]) { delete state[val]; } else { state[val] = 1; }
              update_counts($summary,state,values);
              $el.trigger('update',state);
            });
          });
          update_counts($summary,state,values);
        },
        text: function(state,all) {
          var skipping = {};
          $.each(state,function(k,v) { skipping[k]=1; });
          var on = [];
          var off = [];
          $.each(all,function(i,v) {
            if(skipping[v]) { off.push(v); } else { on.push(v); }
          });
          var out = "None";
          if(on.length<=off.length) {
            out = on.join(', ');
          } else if(on.length) {
            out = 'All except '+off.join(', ');
          }
          if(out.length>20) {
            out = out.substr(0,20)+'...('+on.length+'/'+all.length+')';
          }
          return out;
        },
        visible: function(values) {
          return values && !!values.length;
        }
      }]
    };
  };
})(jQuery);