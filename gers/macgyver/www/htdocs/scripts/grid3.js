/*
 * Ext JS Library 2.0
 * Copyright(c) 2006-2007, Ext JS, LLC.
 * licensing@extjs.com
 * 
 * http://www.extjs.com/license
 */


Ext.onReady(function(){

    Ext.QuickTips.init();
    
    var xg = Ext.grid;

    // shared reader
    var reader = new Ext.data.ArrayReader({}, [
       {name: 'company'},
       {name: 'price', type: 'float'},
       {name: 'change', type: 'float'},
       {name: 'pctChange', type: 'float'},
       {name: 'lastChange', type: 'date', dateFormat: 'n/j h:ia'},
       {name: 'desc'}
    ]);

    // row expander
    var expander = new xg.RowExpander({
        tpl : new Ext.Template(
            '<p><b>Company:</b> {company}<br>',
            '<p><b>Summary:</b> {desc}</p>'
        )
    });

    var grid1 = new xg.Grid3({
        ds: new Ext.data.Store({
            reader: reader,
            data: xg.dummyData
        }),
        cm: new xg.ColumnModel([
            expander,
            {id:'company',header: "Company", width: 40, sortable: true, dataIndex: 'company'},
            {header: "Price", width: 20, sortable: true, renderer: Ext.util.Format.usMoney, dataIndex: 'price'},
            {header: "Change", width: 20, sortable: true, dataIndex: 'change'},
            {header: "% Change", width: 20, sortable: true, dataIndex: 'pctChange'},
            {header: "Last Updated", width: 20, sortable: true, renderer: Ext.util.Format.dateRenderer('m/d/Y'), dataIndex: 'lastChange'}
        ]),
        viewConfig: {
            forceFit:true
        },
        width: 600,
        height: 300,
        expander: expander,
        collapsible: true,
        animCollapse: false,
        title: 'Expander Rows, Collapse and Force Fit',
        iconCls: 'icon-grid',
        renderTo: document.body
    });



    var sm = new xg.CheckboxSelectionModel();
    var grid2 = new xg.Grid3({
        ds: new Ext.data.Store({
            reader: reader,
            data: xg.dummyData
        }),
        cm: new xg.ColumnModel([
            sm,
            {id:'company',header: "Company", width: 200, sortable: true, dataIndex: 'company'},
            {header: "Price", width: 120, sortable: true, renderer: Ext.util.Format.usMoney, dataIndex: 'price'},
            {header: "Change", width: 120, sortable: true, dataIndex: 'change'},
            {header: "% Change", width: 120, sortable: true, dataIndex: 'pctChange'},
            {header: "Last Updated", width: 135, sortable: true, renderer: Ext.util.Format.dateRenderer('m/d/Y'), dataIndex: 'lastChange'}
        ]),
        sm: sm,
        width:600,
        height:300,
        frame:true,
        title:'Framed with Checkbox Selection and Horizontal Scrolling',
        iconCls:'icon-grid',
        renderTo: document.body
    });



    var grid3 = new xg.Grid3({
        ds: new Ext.data.Store({
            reader: reader,
            data: xg.dummyData
        }),
        cm: new xg.ColumnModel([
            new xg.RowNumberer(),
            {id:'company',header: "Company", width: 40, sortable: true, dataIndex: 'company'},
            {header: "Price", width: 20, sortable: true, renderer: Ext.util.Format.usMoney, dataIndex: 'price'},
            {header: "Change", width: 20, sortable: true, dataIndex: 'change'},
            {header: "% Change", width: 20, sortable: true, dataIndex: 'pctChange'},
            {header: "Last Updated", width: 20, sortable: true, renderer: Ext.util.Format.dateRenderer('m/d/Y'), dataIndex: 'lastChange'}
        ]),
        viewConfig: {
            forceFit:true
        },
        width:600,
        height:300,
        title:'Grid with Numbered Rows and Force Fit',
        iconCls:'icon-grid',
        renderTo: document.body
    });


    
    var sm2 = new xg.CheckboxSelectionModel();
    var grid4 = new xg.Grid3({
        id:'button-grid',
        ds: new Ext.data.Store({
            reader: reader,
            data: xg.dummyData
        }),
        cm: new xg.ColumnModel([
            sm,
            {id:'company',header: "Company", width: 40, sortable: true, dataIndex: 'company'},
            {header: "Price", width: 20, sortable: true, renderer: Ext.util.Format.usMoney, dataIndex: 'price'},
            {header: "Change", width: 20, sortable: true, dataIndex: 'change'},
            {header: "% Change", width: 20, sortable: true, dataIndex: 'pctChange'},
            {header: "Last Updated", width: 20, sortable: true, renderer: Ext.util.Format.dateRenderer('m/d/Y'), dataIndex: 'lastChange'}
        ]),
        sm: sm2,

        viewConfig: {
            forceFit:true
        },

        // inline buttons
        buttons: [{text:'Save'},{text:'Cancel'}],
        buttonAlign:'center',

        // inline toolbars
        tbar:[{
            text:'Add Something',
            tooltip:'Add a new row',
            iconCls:'add'
        }, '-', {
            text:'Options',
            tooltip:'Blah blah blah blaht',
            iconCls:'option'
        },'-',{
            text:'Remove Something',
            tooltip:'Remove the selected item',
            iconCls:'remove'
        }],

        cls:'x-panel-blue',
        width:600,
        height:300,
        frame:true,
        title:'Support for standard Panel features such as framing, buttons and toolbars',
        iconCls:'icon-grid',
        renderTo: document.body
    });
});



// Array data for the grids
Ext.grid.dummyData = [
    ['3m Co',71.72,0.02,0.03,'9/1 12:00am'],
    ['Alcoa Inc',29.01,0.42,1.47,'9/1 12:00am'],
    ['Altria Group Inc',83.81,0.28,0.34,'9/1 12:00am'],
    ['American Express Company',52.55,0.01,0.02,'9/1 12:00am'],
    ['American International Group, Inc.',64.13,0.31,0.49,'9/1 12:00am'],
    ['AT&T Inc.',31.61,-0.48,-1.54,'9/1 12:00am'],
    ['Boeing Co.',75.43,0.53,0.71,'9/1 12:00am'],
    ['Caterpillar Inc.',67.27,0.92,1.39,'9/1 12:00am'],
    ['Citigroup, Inc.',49.37,0.02,0.04,'9/1 12:00am'],
    ['E.I. du Pont de Nemours and Company',40.48,0.51,1.28,'9/1 12:00am'],
    ['Exxon Mobil Corp',68.1,-0.43,-0.64,'9/1 12:00am'],
    ['General Electric Company',34.14,-0.08,-0.23,'9/1 12:00am'],
    ['General Motors Corporation',30.27,1.09,3.74,'9/1 12:00am'],
    ['Hewlett-Packard Co.',36.53,-0.03,-0.08,'9/1 12:00am'],
    ['Honeywell Intl Inc',38.77,0.05,0.13,'9/1 12:00am'],
    ['Intel Corporation',19.88,0.31,1.58,'9/1 12:00am'],
    ['International Business Machines',81.41,0.44,0.54,'9/1 12:00am'],
    ['Johnson & Johnson',64.72,0.06,0.09,'9/1 12:00am'],
    ['JP Morgan & Chase & Co',45.73,0.07,0.15,'9/1 12:00am'],
    ['McDonald\'s Corporation',36.76,0.86,2.40,'9/1 12:00am'],
    ['Merck & Co., Inc.',40.96,0.41,1.01,'9/1 12:00am'],
    ['Microsoft Corporation',25.84,0.14,0.54,'9/1 12:00am'],
    ['Pfizer Inc',27.96,0.4,1.45,'9/1 12:00am'],
    ['The Coca-Cola Company',45.07,0.26,0.58,'9/1 12:00am'],
    ['The Home Depot, Inc.',34.64,0.35,1.02,'9/1 12:00am'],
    ['The Procter & Gamble Company',61.91,0.01,0.02,'9/1 12:00am'],
    ['United Technologies Corporation',63.26,0.55,0.88,'9/1 12:00am'],
    ['Verizon Communications',35.57,0.39,1.11,'9/1 12:00am'],
    ['Wal-Mart Stores, Inc.',45.45,0.73,1.63,'9/1 12:00am'],
    ['Walt Disney Company (The) (Holding Company)',29.89,0.24,0.81,'9/1 12:00am']
];

// add in some dummy descriptions
for(var i = 0; i < Ext.grid.dummyData.length; i++){
    Ext.grid.dummyData[i].push('Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Sed metus nibh, sodales a, porta at, vulputate eget, dui. Pellentesque ut nisl. Maecenas tortor turpis, interdum non, sodales non, iaculis ac, lacus. Vestibulum auctor, tortor quis iaculis malesuada, libero lectus bibendum purus, sit amet tincidunt quam turpis vel lacus. In pellentesque nisl non sem. Suspendisse nunc sem, pretium eget, cursus a, fringilla vel, urna.<br/><br/>Aliquam commodo ullamcorper erat. Nullam vel justo in neque porttitor laoreet. Aenean lacus dui, consequat eu, adipiscing eget, nonummy non, nisi. Morbi nunc est, dignissim non, ornare sed, luctus eu, massa. Vivamus eget quam. Vivamus tincidunt diam nec urna. Curabitur velit.');
}