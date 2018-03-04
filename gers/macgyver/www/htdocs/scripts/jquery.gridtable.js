/********************************************************************
 * public domain - keep this copyright header intact
 *
 * (c) 2008 Kai H. Meder - kai_at_meder_dot_info
 *******************************************************************/

// export gridtable-class into global namespace
var gridtable;

(function($) {

if (typeof(functionArgumentsToArray) == 'undefined') {
	function functionArgumentsToArray(args) {
		var arr = [];
		for (var i=0, len=args.length; i<len; ++i) { arr.push(args[i]); }
		return arr;
	}
}
if (typeof(Function.prototype.bindContext) == 'undefined') {
	Function.prototype.bindContext = function() {
		var method = this,
			args   = functionArgumentsToArray(arguments),
			scope  = args.shift();
		return function() {
			return method.apply(scope, args.concat(functionArgumentsToArray(arguments)));
		};
	};
}


// #################################################
// PLUGIN

$.fn.gridtable = function(config) {

	// gridtable-object request
	if (arguments.length == 0) {
		return $(this)[0].gt;
	}
	
	// config
	if (typeof(arguments[0]) == 'object') {
		
		var cfg = $.extend({}, $.gridtable.defaults, arguments[0]);
		
		return this.each(function(){
			var that  = this;
			var $that = $(this);
			
			// DOM expando
			this.gt = new gridtable(this, cfg);
			
			// memory leaking stuff
			$(window).unload(function(){
				$that.unbind();
				that.gt = null;
			});
		});
	}

	// method
	// gridtable('<method>', [arg0, arg1, ...])
	if (typeof(arguments[0]) == 'string') {
		
		var $this = $(this);
		var res = null;
		var len = $this.length;
		for (var i=0; i<len; i++) {
			if ($this[i].gt) {
			
				var gt     = $this[i].gt;
				var method = gt[ arguments[0] ];
				var args   = (arguments.length == 2) ? arguments[1] : [];
				
				if (!method) {
					throw "invalid method";
				}
				
				// if $('...').length > 0, return last result
				res = method.apply(gt, args);
			}
		}
		
		return res;
	}
};



$.gridtable = {
	version: 0.1,
	
	
	// #################################################
	// DEFAULTS
	defaults: {
		width:  null,
		height: null, // BROKEN!
		
		sortParam:    'sort',
		sortDirParam: 'sort_dir',
		pageParam:    'page',
		//filterParam:  'filter',
		
		serialize: {
			add: true,
			addParam: 'add',
			
			remove: true,
			removeParam: 'rm',
			
			edit: true,
			editParam: 'edit', // _<colID> will be appended
			
			seq: true,
			seqParam: 'seq'
		},
		
		error: null, // error-delegate, if null will console.log the error
		
		maskOpacity: 0.5,
		
		paging: false,		// may be jquery-element, e.g. $('#paging-container')
		listPages: true,
		listMaxPages: 5,
		
		// default renderer, if no default specified defaults to escape
		renderer: null,
		xrenderer: null,
		
		autoload: true,
	
		url: '',
		type: 'GET',
		dataType: 'json',
		params: {},
	
		// reader to use, defaults to dataType-specific reader	
		reader: null,
		xreader: null
	},


	// #################################################
	// READERS
	readers: {
		json: function(gt, d) {
								
			if (!d || !d.data) {
				gt.table.trigger('error.gridtable', ['no json.data', gt, d]);
				d.data = [];
			}
			
			if (gt.cfg.paging && d.pages !== 0 && !d.pages) {
				gt.table.trigger('error.gridtable', ['no json.pages', gt, d]);
				d.pages = 1;
			}
			
			gt.totalPages = d.pages;
			
			for (var i=0; i<d.data.length; ++i) {
				var row = gt.newRow(d.data[i]);
				
				for (var j=0; j<gt.cfg.cols.length; ++j) {
					var colID = gt.cfg.cols[j].id;
					var value = d.data[i][colID] || '';
					var cell = gt.newCell(row, j, colID, value);
					//this.cfg.cols[j].renderer.call(this, cell, value);
					gt.cfg.cols[j].renderer(cell, value, gt);
				}
			}
		},
		
		xml: function(gt, d) {
			alert('$.fn.gridtable.readers.xml not implemented');
		}
	},
	
	
	// #################################################
	// RENDERERS
	renderers: {
		raw: function(cell, v) {
			cell.innerHTML = v;
		},
		
		escape: function(cell, v) {
			$(cell).text(v);
		},
		
		uri: function(cell, v) {
			//TODO: XSS
			cell.innerHTML = '<a href="' + v + '" target="_new">' + v + '</a>';
		},
		
		array: function(cell, v) {
			cell.innerHTML = v.join(', ');
		},
		
		ucfirst: function(cell, v) {
			
			$(cell).text( v.substr(0,1).toUpperCase() + v.substr(1) );
		}
	},
	
	
	// #################################################
	// EDITORS
	editors: {
		text: function(cell, value, cfg) {
						
			var $frm = $('<form />').appendTo(cell);
			
			var inp = $('<input name="value" type="text" value="" />')
				.addClass('gt-editor-text')
				.val( value )
				.appendTo( $frm )
				.focus();
		},
		
		checkbox: function(cell, value, cfg) {
			
			var $frm = $('<form />').appendTo(cell);
			
			var v = cfg.value || 1;
			
			var inp = $('<input name="value" type="checkbox" />')
				.addClass('gt-editor-checkbox')
				.val( v )
				.appendTo( $frm );
		},
		
		select: function(cell, value, cfg) {
			
			var $frm = $('<form />').appendTo(cell);
			
			var $sel = $('<select name="value" size="1" />')
				.addClass('gt-editor-select')
				.appendTo( $frm );
			
			var opts = cfg.options || {};
			
			for (var optVal in opts) {
				var $opt = $('<option />')
					.attr('value', optVal)
					.text( opts[optVal] )
					.appendTo( $sel );
			}
			
			$sel.val( value );
		}
	},
	
	
	// #################################################
	// FILTERS
	filters: {
	/*
		numeric: function(c, data, cfg) {
			
			var $sel = $('<select size="1" name="op" />')
				.addClass('gt-filter-numeric-op')
				.appendTo( c );
			
			$('<option />').attr('value', 'lt').text(' < ' ).appendTo( $sel );
			$('<option />').attr('value', 'le').text(' <= ').appendTo( $sel );
			$('<option />').attr('value', 'gt').text(' > ' ).appendTo( $sel );			
			$('<option />').attr('value', 'ge').text(' >= ').appendTo( $sel );
			$('<option />').attr('value', 'eq').text(' = ' ).appendTo( $sel );
			
			$sel.val( data.op || 'eq' );
			
			$('<input type="text" name="f" value="" />')
				.addClass('gt-filter-numeric')
				.val( data.f )
				.appendTo( c );
		},
		
		string: function(c, data, cfg) {
			
			$('<input type="text" name="f" value="" />')
				.val( data.f || '' )
				.appendTo( c );
		},
		
		select: function(c, data, cfg) {
			
			var $sel = $('<select name="f" size="1" />')
				.addClass('gt-editor-select')
				.appendTo( c );
			
			var opts = cfg.options || {};
			
			for (var optVal in opts) {
				var $opt = $('<option />')
					.attr('value', optVal)
					.text( opts[optVal] )
					.appendTo( $sel );
			}
			
			$sel.val( data.f || '' );
		}
		*/
	}
};


// #################################################
// CLASS - IMPLEMENTATION
gridtable = function(tableEl, cfg) {

	this.table = $(tableEl);
	this.cfg   = cfg;
		
	this.PKidx = null;
	
	this.headerCols = null;
		
	this.mask = null;
	this.maskUpdater = null;
	this.maskLastPos = null;
				
	this.currSort    = null;
	this.currSortDir = null;
	this.currFilters = [];
		
	this.totalPages = null;
	this.currPage   = (cfg.paging) ? 1 : null;
	
	this.init();
	this.transform();
};
		
// public
gridtable.prototype.sort = function(colID, sortDir, load) {
			
	this.currSort    = colID;
	this.currSortDir = (sortDir || 'asc').toLowerCase();
	
	if (load == null || load) {
		this.load();
	}
	
	//this.table.trigger('sort.gridtable', [ colID, sortDir, load ]);
};
		
// public
gridtable.prototype.unsort = function(load) {
	
	this.currSort    = null;
	this.currSortDir = null;
	
	if (load == null || load) {
		this.load();
	}
};

// public
gridtable.prototype.firstPage = function() { this.page(1); };
gridtable.prototype.prevPage  = function() { this.page(this.currPage - 1); };
gridtable.prototype.nextPage  = function() { this.page(this.currPage + 1); };
gridtable.prototype.lastPage  = function() { this.page(this.totalPages);   };
		
// public
gridtable.prototype.page = function(p, load) {
	this.currPage = Math.max(1, Math.min(this.totalPages, p));
	
	if (load == null || load) {
		this.load();
	}
};
		
// public
gridtable.prototype.load = function() {
		
	this.table.trigger('preload.gridtable', [ this ]);
	
	this.blockView();
	
	var params = $.extend({}, this.cfg.params);
									
	// sort
	if (this.currSort) {
		params[this.cfg.sortParam]    = this.currSort
		params[this.cfg.sortDirParam] = this.currSortDir;	
	}
						
	// paging	
	if (this.currPage) {
		params[this.cfg.pageParam] = this.currPage;
	}
	
	/*
	// filters
	if (this.currFilters.length > 0) {
		// TODO filters
		//params[this.cfg.filterParam] = ...
	}
	*/
	
	// shoot!
	$.ajax({
		type:     this.cfg.type.toUpperCase(),
		url:      this.cfg.url,
		data:     params,
		dataType: this.cfg.dataType,
		
		success:  this.loadDlg.bindContext(this),
		error:    this.errorDlg.bindContext(this)
	});
};
				
// public
/*
old pre-loading code, which is async -> sucks
gridtable.prototype.addRow = function(data, cb) {
	var that = this;
	
	var add = function(d) {
		that.table.addClass('gt-dirty');
		
		var row = that.newRow(d);
		$(row).addClass('gt-dirty').addClass('gt-added');
		
		for (var j=0; j<that.cfg.cols.length; ++j) {
			
			var colID = that.cfg.cols[j].id;
			var value = d[colID] || '';
			
			var cell = that.newCell(row, j, colID, value);
			//that.cfg.cols[j].renderer.call(this, cell, value);
			that.cfg.cols[j].renderer(cell, value);
		}
		
		that.updateDataView();
		
		// callback with new row element
		if (cb) {
			cb( row );
		}
	};
	
	
	// already loaded?
	if (this.table.is('.gt-loaded')) {
		add(data);
	
	// load first
	} else {
		this.table.bind('loaded.gridtable', function() { add(data); });
		this.load();
	}
};
*/
gridtable.prototype.addRow = function(d) {
	this.table.addClass('gt-dirty');
	
	var row = this.newRow(d);
	$(row).addClass('gt-dirty').addClass('gt-added');
		
	for (var j=0; j<this.cfg.cols.length; ++j) {
		
		var colID = this.cfg.cols[j].id;
		var value = d[colID] || '';
		
		var cell = this.newCell(row, j, colID, value);
		//that.cfg.cols[j].renderer.call(this, cell, value);
		this.cfg.cols[j].renderer(cell, value);
	}
	
	this.updateDataView();
	
	return row;
};
						
// public
gridtable.prototype.removeRow = function(rowEl) {
			
	this.table.addClass('gt-dirty');
	
	if (rowEl.jquery) rowEl = rowEl[0];
	$(rowEl).addClass('gt-dirty').addClass('gt-removed').removeClass('gt-added');
	
	this.updateDataView();
};
					
// public
gridtable.prototype.updateCell = function(row, colID, value) {
		
	var $cols = $(row).find('> td');
	
	var colIdx = -1;
	var $cell, cell;
	
	for (var i=0; i<this.cfg.cols.length; i++) {
		if (this.cfg.cols[i].id == colID) {
			colIdx = i;
			$cell = $cols[i];
			cell  = $cell[0];
			break;
		}
	}
	
	if (!cell) {
		throw 'cell not found! colID='+colID+'/value='+value;
	}
	
	cell.gt_colidx = colIdx;
	cell.gt_colid  = colID;
	cell.gt_value  = value;
	
	/*
	$cell
		.data('gt_colidx', colIdx)
		.data('gt_colid',  colID)
		.data('gt_value',  value);
	*/
	
	this.cfg.cols[colIdx].renderer($cell, value);
};
		
// public
gridtable.prototype.empty = function() {
	
	this.table
		.find('> tbody > tr')
		.not('.gt-dirty')
		.not('.gt-x')
		.remove();
};

// helper
gridtable.prototype.newRow = function(data) {
	
	var rowEl = document.createElement('tr');
	this.table.find('> tbody').append( rowEl );
	rowEl.gt_data = data;
	return rowEl;
	
	//var row = $('<tr />').appendTo( this.table.find('> tbody') );
	//row.data('gt_data', {bar: 'FOO'});
	//row.data('gt_data', {});
	//row.data('gt_data', [ 'foo', 'bar' ]);
	//row.data('gt_data', 'FOCKIN HELL');
	//return row;
};
		
// helper
gridtable.prototype.newCell = function(rowEl, colIdx, colID, value) {
	
	var cellEl = document.createElement('td');
	
	rowEl.appendChild( cellEl );
	
	cellEl.gt_colidx = colIdx;
	cellEl.gt_colid  = colID;
	cellEl.gt_value  = value;
	
	if (colIdx == this.PKidx) {
		rowEl.gt_pk = value;
	}
	
	return cellEl;
	/*
	return cell = $('<td />')
		.data('gt_colidx', colIdx)
		.data('gt_colid',  colID)
		.data('gt_value',  value)
		.appendTo( row );
	*/
};
				
// private
gridtable.prototype.sortDlg = function(colIdx, e) {
	
	var id = this.cfg.cols[colIdx].id;
	
	var $sort = this.headerCols.eq(colIdx).find('.gt-sort');
	
	// asc -> desc
	if ($sort.is('.gt-sort-asc')) {
		this.sort(id, 'desc');
	}
				
	// desc -> default/none
	else if ($sort.is('.gt-sort-desc')) {
		
		// searching for default-sort col
		for (var i=0; i<this.cfg.cols.length; ++i) {
			if (this.cfg.cols[i].defaultSort) {
				this.sort(this.cfg.cols[i].id, this.cfg.cols[i].defaultSortDir);
				return; // STOP
			}
		}
		
		// no default-sort found, unsort
		this.unsort();
	}
	
	// none -> asc
	else {
		this.sort(id, 'asc');
	}
};

// private
/*
gridtable.prototype.filterDlg = function(colIdx, e) {
	//TODO
};
		
// private
gridtable.prototype.filterApplyDlg = function(e) {
	//TODO
};
*/
		
// private
gridtable.prototype.loadDlg = function(data) {
	
	this.empty();
	
	//this.cfg.reader.call(this, data);
	this.cfg.reader(this, data);
		
	this.updateView();
	this.unblockView();
	
	this.table.addClass('gt-loaded').trigger('postload.gridtable', [ this ]);
};
		
// private
gridtable.prototype.errorDlg = function() {
	
	var args = [ this ];
	for (var i=0; i<arguments.length; ++i) {
		args.push(arguments[i]);
	}
	
	this.table.trigger('error.gridtable', args);
};
				
// public
gridtable.prototype.serialize = function() {
	var that = this;
	
	var d = [];
	
	if (this.PKidx == null) {
		throw "PK not specified, use 'PK: true'-property on one col"; 
	}
	
	// PK-cell
	var PKsel = 'td:nth-child(' + (this.PKidx + 1) + ')';

	// collect dirty-fields: added, removed, edited
	this.table.find('> tbody > tr.gt-dirty').each(function(seq) {
		var $tr = $(this);
		
		// added
		if (that.cfg.serialize.add) {
			$tr.filter('.gt-added').find(PKsel).each(function() {
				
				d.push(that.cfg.serialize.addParam + '[]=' + encodeURIComponent(this.gt_value));
			});
		}

		// removed
		if (that.cfg.serialize.remove) {
			$tr.filter('.gt-removed').find(PKsel).each(function() {
				
				d.push(that.cfg.serialize.removeParam + '[]=' + encodeURIComponent(this.gt_value));
			});
		}
										
		// edited
		if (that.cfg.serialize.edit) {
			
			$tr.filter('.gt-edited').find('td.gt-edited').each(function() {
				
				var pk     = $(this).siblings(PKsel)[0].gt_value;
				var param  = that.cfg.serialize.editParam + '[' + this.gt_colid + '][' + pk + ']';
				
				d.push(param + '=' + encodeURIComponent(this.gt_value));
			});
		}
	});
	
	// sequence
	if (this.cfg.serialize.seq) {
		this.table.find('> tbody > tr:not(.gt-removed)').each(function(seq) {
			$(this).find(PKsel).each(function() {
				
				d.push(that.cfg.serialize.seqParam + '[' + seq + ']=' + encodeURIComponent(this.gt_value));
			});
		});
	}
	
	// explicitly serialize - col[x].serialize
	var rows = this.table.find('> tbody > tr:not(.gt-removed)');
	for (var i=0; i<this.cfg.cols.length; ++i) {
		if (this.cfg.cols[i].serialize) {
			rows.find('> td:nth-child(' + (i+1) + ')').each(function() {
				
				var pk    = $(this).siblings(PKsel)[0].gt_value;
				var param = this.gt_colid + '[' + pk + ']';
				
				d.push(param + '=' + encodeURIComponent(this.gt_value));
			});
		}
	}
	
	return d.join('&');
};
				
// public
gridtable.prototype.blockView = function() {
							
	if (!this.mask) {
		this.mask = $('<div />')
					.addClass('gt-mask')
					.hide()
					.insertAfter(this.table)
					.append('<div />');
	}

	this.mask
		.width(this.table.width())
		.height(this.table.height())
		.css({ opacity: this.cfg.maskOpacity });
	
	this.updateMask();
	this.mask.show();
	this.maskUpdater = window.setInterval(this.updateMask.bindContext(this), 100);
};
		
// public
gridtable.prototype.unblockView = function() {
	if (this.mask) {
		this.mask.hide();
	}
	
	if (this.maskUpdater) {
		window.clearInterval(this.maskUpdater);
		this.maskUpdater = null;
	}
};
		
// private
gridtable.prototype.updateMask = function() {
	
	var pos = this.table.offset();
	
	// no change ...
	if (this.maskLastPos &&
		this.maskLastPos.top == pos.top &&
		this.maskLastPos.left == pos.left) {
		return; //STOP
	}
	
	// reposition
	this.mask.css({
		top:    pos.top,
		left:   pos.left,
		width:  this.table.width(),
		height: this.table.height()
	});
	
	this.maskLastPos = pos;
};
		
// public
gridtable.prototype.updateView = function() {
				
	this.updateHeaderView();
	this.updateFooterView();
	this.updatePagingView();
	this.updateDataView();
};
		
// public
gridtable.prototype.updateHeaderView = function() {
	
	// sorting
	for (var i=0; i<this.cfg.cols.length; ++i) {
		if (!this.cfg.cols[i].sort) {
			continue;
		}
	
		var $sort = this.headerCols.eq(i).find('.gt-sort'); 
	
		// clean sorting
		$sort.removeClass('gt-sort-asc').removeClass('gt-sort-desc').removeClass('gt-sort-none');
		
		// new sort-class
		$sort.addClass(
			(this.currSort == this.cfg.cols[i].id) ?
				'gt-sort-'+this.currSortDir :
				'gt-sort-none'
		);
	}
};
		
		
// public
gridtable.prototype.updateFooterView = function() {
	
	// was for paging ...
};


// public
gridtable.prototype.updatePagingView = function() {
	
	if (!this.cfg.paging) {
		return;
	}
				
	// container
	var paging = (this.cfg.paging.jquery) ? this.cfg.paging : this.table.find('> tfoot > tr.gt-paging > td');
	
	// shortcuts
	var page = this.currPage || 1;
	var total = this.totalPages || 1;
	
	// TODO: loading-indicator broken?
	// load - stop the loading indicator
	var $load = paging.find('.gt-page-load').removeClass('gt-page-loading');
		
	// first
	var $first = paging.find('.gt-page-first').unbind('click');
	
	if (this.currPage > 1) {
		$first.removeClass('gt-page-first-off').css({cursor: 'pointer'})
			.click(this.firstPage.bindContext(this));
			
	} else {
		$first.addClass('gt-page-first-off').css({cursor: 'default'});
	}
	
	
	// prev
	var $prev = paging.find('.gt-page-prev').unbind('click');
	
	if (this.currPage > 1) {
		$prev.removeClass('gt-page-prev-off').css({cursor: 'pointer'})
			.click(this.prevPage.bindContext(this));
			
	} else {
		$prev.addClass('gt-page-prev-off').css({cursor: 'default'});
	}
	
	
	// selection
	var $sel = paging.find('.gt-page-sel');
	if (this.cfg.listPages) {
		
		// TODO
		//if (total > this.cfg.listMaxPages)
		var $ol = $('<ol />').appendTo( $sel.empty() );
		
		for (var p=1; p<=total; ++p) {
		
			var $li = $('<li />').text( p ).appendTo( $ol );
				
			if (p == page) {
				$li.addClass('gt-current-page');
			}
			
			$li.click(function(p, e) {
				
				$load.addClass('gt-page-loading');
				this.page( p );
				
			}.bindContext(this, p));
			
			$li.hover(
				function() { $(this).addClass('gt-hover');    },
				function() { $(this).removeClass('gt-hover'); }
			);
		}
	} else {
		$sel.text(page + ' / ' + total);
	}
	
				
	// next
	var $next = paging.find('.gt-page-next').unbind('click');
	
	if (this.currPage < this.totalPages) {
		$next.removeClass('gt-page-next-off').css({cursor: 'pointer'})
			.click(this.nextPage.bindContext(this));
	
	} else {
		$next.addClass('gt-page-next-off').css({cursor: 'default'});
	}
	
	
	// last
	var $last = paging.find('.gt-page-last').unbind('click');
	
	if (this.currPage < this.totalPages) {
		$last.removeClass('gt-page-last-off').css({cursor: 'pointer'})
			.click(this.lastPage.bindContext(this));
	
	} else {
		$last.addClass('gt-page-last-off').css({cursor: 'default'});
	}
	
				
	// info
	var $info = paging.find('.gt-page-info');
	//TODO: records per page
	// showing records: 1-10 of 10000	
};
		
// public
gridtable.prototype.updateDataView = function() {
	var that = this;
				
	// stripe
	this.table.find('> tbody > tr').removeClass('gt-odd').removeClass('gt-even')
		.not('.gt-x').not('.gt-dirty')
		.filter(':odd').addClass('gt-odd').end()
		.filter(':even').addClass('gt-even');
							
	// hover
	//this.table.find('> tbody > tr').unbind('hover').unbind('mouseover').unbind('mouseout').removeClass('gt-hover')
	this.table.find('> tbody > tr').unbind('hover').unbind('mouseenter').unbind('mouseleave').removeClass('gt-hover')
		.not('.gt-x').not('.gt-dirty').hover(function() {
		$(this).addClass('gt-hover');
	}, function() {
		$(this).removeClass('gt-hover');
	});
	
	for (var i=0; i<this.cfg.cols.length; ++i) {
		
		var tdSel = '> tbody > tr > td:nth-child(' + (i + 1) + ')';
	
		// editor
		if (this.cfg.cols[i].editor) {
			this.table.find(tdSel).addClass('gt-edit');
		}
	}
};
	
// private
gridtable.prototype.dispatchClick = function(e) {
	var that = this;

	var t = e.target;
	var $t = $(t);
	//console.log('dispatchClick', t, e);
	
	// editor
	if ($t.is('td.gt-edit')) {
		this.editorInit(t);
	}
};

// private
gridtable.prototype.dispatchKey = function(e) {
			
	var t = e.target;
	var $t = $(t);
	//console.log('dispatchKey', t, e);
				
	// ESC
	if (e.keyCode == 27) {
		this.table.trigger('editorCancel.gridtable', [ this ]);		
	}
};
				
// private
gridtable.prototype.editorInit = function(cell) {
	var that = this;
	
	var $cell = $(cell);
	
	if ($cell.is('.gt-editing') || $cell.is('.gt-removed')) {
		return; // STOP
	}
				
	// other cells being edited? -> auto save
	if ($cell.parents('tbody').find('> tr > td.gt-editing').length > 0) {
		this.table.trigger('editorSave.gridtable', [ this ]);
	}
	
	$cell.addClass('gt-editing');
	
	// store initial value
	if (!cell.gt_initvalue) {
		cell.gt_initvalue = cell.gt_value;
	}
	
	// clean
	cell.innerHTML = '';
	
	// call editor
	var editor = this.cfg.cols[cell.gt_colidx].editor;
	var editorCfg = this.cfg.cols[cell.gt_colidx].editorCfg || {};
	
	//TODO: do not bind, explicitly pass this-argument
	editor.call(this, cell, cell.gt_value, editorCfg);
		
	// if a form has been added, intercept submit
	$(cell).find('form').each(function() {
		this.onsubmit = function() {
		
			// TODO: broken due to event-handling removal?
			that.table.trigger('editorSave.gridtable', [ this ]);
			return false;
		};
	});
};
		
// private
gridtable.prototype.editorSaveDlg = function(e, value) {
	
	// find cell
	var $cell = this.table.find('> tbody > tr > td.gt-editing');
				
	if ($cell.length == 0) {
		//console.log('editorSaveDlg', 'no active editing cell found');
		return; // STOP
	}
	
	var cell = $cell[0];
	
	// no value specified, try to get from a form
	if (!value) {
		
		var $frm = $cell.find('form');
		if ($frm.length == 0) {
			throw 'no value specified and no form found to get value from';
		}
		
		var valEl = $frm[0].elements['value'];
		if (!valEl) {
			throw 'no value specified an no form.value-element found'; 
		}
		
		value = valEl.value;
	}
	
	// save back raw value
	cell.gt_value = value;
	
	// render new value
	this.cfg.cols[cell.gt_colidx].renderer(cell, value);
	
	$(cell).removeClass('gt-editing');
	this.editorSetDirty(cell);
};
		
// private
gridtable.prototype.editorCancelDlg = function(e) {
	
	// find cell
	var $cell = this.table.find('> tbody > tr > td.gt-editing');
	
	if ($cell.length == 0) {
		//console.log('editorCancelDlg', 'no active editing cell found');
		return; // STOP
	}
				
	var cell = $cell[0];
	
	// clear
	cell.innerHTML = '';
	
	// render current cell-value
	this.cfg.cols[cell.gt_colidx].renderer(cell, cell.gt_value);

	$(cell).removeClass('gt-editing');
	this.editorSetDirty(cell);
};
		
// private - set dirty flags if dirty
gridtable.prototype.editorSetDirty = function(cell) {

	var $cell = $(cell);
	
	// changed -> dirty
	if (cell.gt_initvalue && cell.gt_initvalue != cell.gt_value) {
		
		$cell.addClass('gt-edited').addClass('gt-dirty')
			.parent().addClass('gt-edited').addClass('gt-dirty')
			.parents('table').addClass('gt-dirty');

	// not changed -> not dirty
	} else {
		
		$cell.removeClass('gt-edited').removeClass('gt-dirty');
		$tr  = $cell.parent();
		$tbl = $tr.parents('table');
		
		// remove edited-flag from row
		if ($cell.siblings('.gt-edited').length == 0) {
			$tr.removeClass('gt-edited');
		}
		
		// remove dirty-flag from row
		if (!$tr.is('.gt-added') && !$tr.is('.gt-removed') && $cell.siblings('.gt-dirty').length == 0) {
			$tr.removeClass('gt-dirty');
			
			// remove dirty-flag from table
			if ($tr.siblings('tr.gt-dirty').length == 0) {
				$tbl.removeClass('gt-dirty');
			}
		}
	}
};
	
// private
gridtable.prototype.init = function() {
	var that = this;
				
	// default reader
	if (this.cfg.xreader) {
		this.cfg.reader = $.gridtable.readers[ this.cfg.xreader ];
	}
	
	// fallback to datatype-specific default reader (json -> json-reader)
	if (!this.cfg.reader) {
		this.cfg.reader = $.gridtable.readers[ this.cfg.dataType ];
	}
				
	// default renderer
	if (this.cfg.xrenderer) {
		this.cfg.renderer = $.gridtable.renderers[ this.cfg.xrenderer ];
	}
	
	// fallback to escape
	if (!this.cfg.renderer) {
		this.cfg.renderer = $.gridtable.renderers['escape'];
	}
	
	// init cols
	for (var i=0; i<this.cfg.cols.length; ++i) {
		
		// enforce id
		if (!this.cfg.cols[i].id) {
			throw 'no col.id in col #' + i;
		}
		
		// PK
		if (this.cfg.cols[i].PK) {
			this.PKidx = i;
		}
		
		// width
		if (!this.cfg.cols[i].width) {
			this.cfg.cols[i].width = '*'; // dynamic
		}
		
		// renderer
		if (this.cfg.cols[i].xrenderer) {
			this.cfg.cols[i].renderer = $.gridtable.renderers[ this.cfg.cols[i].xrenderer ];
		}
		
		// fallback to default renderer
		if (!this.cfg.cols[i].renderer) {
			this.cfg.cols[i].renderer = this.cfg.renderer;
		}
		
		// editor
		if (this.cfg.cols[i].xeditor) {
			this.cfg.cols[i].editor = $.gridtable.editors[ this.cfg.cols[i].xeditor ];
		}
		
		// sort
		if (this.cfg.cols[i].defaultSort && !this.cfg.cols[i].defaultSortDir) {
			this.cfg.cols[i].defaultSortDir = 'asc';
		}
		
		/*
		// filters
		if (!this.cfg.cols[i].filters) {
			this.cfg.cols[i].filters = [];
		}
				
		// add filter-shortcut filters-array 
		if (this.cfg.cols[i].filter) {
			this.cfg.cols[i].filters.push({
				filter:  this.cfg.cols[i].filter,
				cfg:     this.cfg.cols[i].filterCfg || {}
			});
			this.cfg.cols[i].filter    = null;
			this.cfg.cols[i].filterCfg = null;
		}
		
		// add xfilter-shortcut to filters-array 
		if (this.cfg.cols[i].xfilter) {
			this.cfg.cols[i].filters.push({
				filter:  $.gridtable.filters[ this.cfg.cols[i].xfilter ],
				cfg:     this.cfg.cols[i].filterCfg || {}
			});
			
			this.cfg.cols[i].xfilter   = null;
			this.cfg.cols[i].filterCfg = null;
		}
		*/
	}
	
	/*
	// DEPRECATED IN FAVOUR OF $('...').gridtable('<public>', ...);
	 
	// EVENT DISPATCHING
	var publics = ['sort', 'unsort',
		'firstPage', 'prevPage', 'nextPage', 'lastPage', 'page',
		'load', 'addRow', 'removeRow', 'updateCell', 'empty', 'serialize',
		'blockView', 'unblockView', 'updateMask', 'updateView',
		'updateHeaderView', 'updateFooterView', 'updatePagingView', 'updateDataView'];
	
	$.each(publics, function(i, fn) {
		var evt = fn + '.gridtable';
			
		that.table.bind(evt, function() {
			var args = [];
			// skip [0] event
			for (var i=1; i<arguments.length; ++i) {
				args.push(arguments[i]);
			}
						
			//if (window.console) console.log('EVT dispatching to ' + fn, args);
			that[fn].apply(that, args);
		});
	});
	*/
	
	// default error-handler
	if (!this.cfg.error) {
		var alerted = false;
		this.cfg.error = function() {
			
			// alert only once
			if (!alerted) {
				alert('gridtable component failed miserably!');
				alerted = true;
			}

			// dump error to console
			if (window.console) {
				console.error(arguments);
			}
		};
	}
	this.table.bind('error.gridtable', this.cfg.error);
};
		
// private
gridtable.prototype.transform = function() {
	var that = this;
	
	this.table.addClass('gridtable');
				
	// thead
	if (this.table.find('> thead').length == 0) {
		this.table.prepend('<thead />');
	}
	
	// tbody
	if (this.table.find('> tbody').length == 0) {
		this.table.append('<tbody />');
	}
		
	// tfoot
	if (this.table.find('> tfoot').length == 0) {
		this.table.append('<tfoot />');
	}
	
	// header
	var $trs = this.table.find('> thead > tr:not(.gt-x)'); 
	var $tr;
	
	if ($trs.length == 0) {
		$tr = $('<tr />').appendTo( this.table.find('> thead') );
	} else {
		$tr = $trs.eq(0);
	}
	
	var $ths = $tr.find('> th');
	for (var i=0; i<this.cfg.cols.length; ++i) {
		
		var $th, lbl;
		
		if ($ths.length == 0) {
			$th = $('<th />').appendTo( $tr );
			lbl = this.cfg.cols[i].label || this.cfg.cols[i].id;
		} else {
			$th = $ths.eq(i);
			lbl = $th.text();
			$th.empty();
		}
			
		if (this.cfg.cols[i].sort && $th.find('.gt-sort').length == 0) {
		
			$('<span />')
				.addClass('gt-sort')
				.appendTo( $th )
				//.click(this.sortDlg.bindContext(this, i));
		}
		
		var $lbl = $('<span />')
			.addClass('gt-label')
			.text( lbl )
			.appendTo( $th );
			
		if (this.cfg.cols[i].sort) {
			//$lbl.click(this.sortDlg.bindContext(this, i));
			$th.addClass('gt-sort').click(this.sortDlg.bindContext(this, i));
		}
		
		/*
		if (this.cfg.cols[i].filters.length > 0) {
			$('<span />')
				.addClass('gt-filter')
				.appendTo( $th )
				.click(this.filterDlg.bindContext(this, i));
		}
		*/
	}
	
	this.headerCols = this.table.find('> thead > tr:not(.gt-x) > th');
	
	
	/* // overflow:auto on tbody SUCKS
	if (this.cfg.height) {
		
		// create one row - empty tbody with fixed height sucks even more
		if (this.table.find('tbody tr').length == 0) {
			var tr = '<tr>';
			for (var i=0; i<this.headerCols.length; ++i) {
				tr += '<td>&nbsp;</td>';
			}					
			tr += '</tr>';
			$(tr).appendTo(this.table.find('tbody'));
		}
		
		var availHeight = this.cfg.height - this.table.find('thead').height() - this.table.find('tfoot').height();
		
		this.table.find('tbody')
			.height( availHeight )
			.css('overflow', 'auto');
	}
	*/
	
	if (this.cfg.width) {
		var w = (this.cfg.width <= 1) ? this.cfg.width*100+'%' : this.cfg.width+'px';
		this.table.css('width', w);
	}
	
	
	var colgroup = this.table.find('> colgroup');			

	// create new colgroup
	if (colgroup.length == 0) {
		colgroup = $('<colgroup />').prependTo( this.table );
	}

	for (var i=0; i<this.cfg.cols.length; ++i) {
		
		// colgroup
		if (colgroup) {
			colgroup.append('<col width="' + this.cfg.cols[i].width + '" />');
		}
		
		// sort - set default sort
		if (this.cfg.cols[i].sort && this.cfg.cols[i].defaultSort) {
			this.sort(this.cfg.cols[i].id, this.cfg.cols[i].defaultSortDir, false);
		}
		
		// resize
		if (this.cfg.cols[i].resize) {
			// TODO resize
		}
		
		// filters
		/*
		if (this.cfg.cols[i].filters.length > 0) {
			this.headerCols.eq(i).find('.gt-filter').click(this.filterDlg.bindContext(this, i));					
		}
		*/
		
		// edit
		if (this.cfg.cols[i].editor) {
			this.headerCols.eq(i)
				.addClass('gt-edit')
				.addClass('tooltip')
				.attr('title', 'This Column is editable - click on a Cell');
		}
	}
				
	// paging
	if (this.cfg.paging) {
		
		var p;
						
		// if paging is an jquery-element use it
		if (this.cfg.paging.jquery) {
		
			p = this.cfg.paging;
			
		// check footer-row
		} else {
			p = this.table.find('> tfoot > tr.gt-paging');
			
			// create footer row
			if (p.length == 0) {
				var tr = $('<tr />')
							.addClass('gt-paging')
							.appendTo( this.table.find('> tfoot') );
			
				p = $('<td colspan="' + this.headerCols.length + '"></td>').appendTo( tr );
			}
		}
		
		var cls = {
			'gt-page-first': '<<',
			'gt-page-prev':  '<',
			'gt-page-sel':   '',
			'gt-page-next':  '>',
			'gt-page-last':  '>>',
			'gt-page-load':  '',
			'gt-page-info':  ''
		};
		
		// create a span for each class
		for (var c in cls) {
			if (p.find('.'+c).length == 0) {
				$('<span />').text( cls[c] ).addClass( c ).appendTo(p);
			}
		}
	}
	
	// general event handlers
	this.table.click(this.dispatchClick.bindContext(this));
	this.table.keyup(this.dispatchKey.bindContext(this));
	this.table.bind('editorSave.gridtable',   this.editorSaveDlg.bindContext(this));
	this.table.bind('editorCancel.gridtable', this.editorCancelDlg.bindContext(this));
	
	// auto load
	if (this.cfg.autoload) {
		this.load();
	} else {
		this.updateView();
	}
};


})(jQuery);