/*
 * ElevationPanel.java
 *
 * Created on June 12, 2008
 * by Jeremy Perkins
 * 
 * This is a test panel that gets a random number from the
 * backend.  This is a good starting point for making a new
 * panel.
 */

package org.veritas.client;

import java.util.Date;

import com.google.gwt.user.client.Timer;
import com.google.gwt.user.client.Command;
import com.google.gwt.user.client.Window;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.user.client.ui.Image;
import com.google.gwt.user.client.ui.HorizontalPanel;
import com.google.gwt.user.client.ui.ListBox;
import com.google.gwt.user.client.ui.HTML;
import com.google.gwt.user.client.ui.FlowPanel;
import com.google.gwt.user.client.ui.ChangeListener;
import com.google.gwt.user.client.ui.Widget;
import com.google.gwt.user.client.ui.Button;
import com.google.gwt.user.client.ui.ClickListener;
import com.google.gwt.user.client.ui.PopupPanel;
import com.google.gwt.http.client.*;
import com.google.gwt.json.client.*;
import com.google.gwt.user.client.Random;


/**
 *
 * @author jperkins
 */
public class ElevationPanel extends VerticalPanel{
    
    //Set up the default panel which has the basic 
    //layout of our little squares with some functions
    //and methods already defined.
    private defaultPanel panel = new defaultPanel("Elevation");
    private static Image smallChart = new Image();
    private static Image bigChart = new Image();
    private ChartPanel chartPanel = new ChartPanel();
    
    //Need a bunch of options stored for the Charts
    private static String sources = "Crab,1.459677,0.384225:";
    
    //Actually create the panel here.
    public ElevationPanel() {

	panel.ServerReply.setPixelSize(400,356);
	panel.lblServerReplyFtr.setPixelSize(456,20);
	        
        panel.infoPanel.setHTML("<h2>Elevation Panel</h2>" +
				"<p>The elevation panel displays elevation "+
				"curves for user-selected sources. " +
				"It will also display the local time and " +
				"the start and stop time as vertical lines." +
				"To select sources, use the 'settings' menu " +
				"item from the main 'El. Chart' menu.  In " +
				"the settings panel, you can select multiple " +
				"sources from the source groups set up within " +
				"the tracking program.  If you add a source " +
				"to the database, you might have to reload " +
				"arraymon for them to appear in this panel.</p>");
        
        panel.mainMenu.addItem("Load Now",LoadNow);
	panel.mainMenu.addItem("Settings",chartSettings);
        panel.refreshMenu.addItem("5 min", refreshM);
        panel.refreshMenu.addItem("10 min", refreshL);
        panel.refreshMenu.addItem("Off", refreshOff);
        
        //Initialize everything
        t.run();
        t.scheduleRepeating(300000+Random.nextInt(1000));
        addStyleName("oversize");
        add(panel);
        
    }
        
    //This is the main command that connects Asynchronously to the
    //backend via an http connection.  The data are sent via a JSON
    //interface.  You should modify this function for different
    //functions.
    private Command LoadNow = new Command() {
	    public void execute(){
       	    
		//Set the display to a differnt color to indicate
		//that it's refreshing.
		panel.ServerReply.setStyleName("blinkreply");

		String url = "<img src=\"" + getImageURL("tiny") + "\"/>";
		
		smallChart.setUrl(url);
		panel.ServerReply.setHTML(url);

		Date d = new Date();
		panel.lblServerReplyFtr.setText(d.toString());
	    }	
	};

    //Get a properly formatted url for the image
    private String getImageURL(String size){

	Date now = new Date();
	int year = now.getYear() + 1900;
	int month = now.getMonth() + 1;
	int date = now.getDate();
	int hours = now.getHours();
	int mins = now.getMinutes();
	int secs = now.getSeconds();
	String datef = year + "-" + month + "-" + date + "z" + hours + ":"
	    + mins + ":" + secs;
	
	String url = "cgi-bin/elevation_plotter.pl"
	    +"?"+datef+"&"+sources+"&"+size+"&"+Random.nextInt();
	
	return url;

    }
	    
    //This is the main timer for this panel
    public Timer t = new Timer() {
        public void run() {
            LoadNow.execute();
        }
    };

    //Restarts the timer to a user defined time
    public void RefreshTimer(int time){
        t.cancel();
        t.scheduleRepeating(time);
        panel.lblServerReplyFtr.setText("Refresh set to "+String.valueOf(time/1000)+" seconds");
    }
    
    //Medium Length Timer
    private Command refreshM = new Command() {
        public void execute(){
            RefreshTimer(300000);
        }
    };
    
    //Long Length Timer
    private Command refreshL = new Command() {
        public void execute(){
            RefreshTimer(600000);
        }
    };
    
    //Command to turn off the timer which disables
    //The refresh.
    private Command refreshOff = new Command() {
        public void execute(){
            t.cancel();
            panel.lblServerReplyFtr.setText("Refresh Off");
        }
    };


    private Command chartSettings = new Command() {
	    public void execute(){

		final defaultPopUp chartPop = new defaultPopUp(chartPanel);

		chartPop.setPopupPositionAndShow(new PopupPanel.PositionCallback() {
			public void setPosition(int offsetWidth, int offsetHeight) {
			    int left = (Window.getClientWidth() - offsetWidth) / 2;
			    int top = (Window.getClientHeight() - offsetHeight) /2;
			    chartPop.setPopupPosition(left,top);
			}
		    });
	    }
	};

    
    private class ChartPanel extends HorizontalPanel{
	
	private VerticalPanel chartControl = new VerticalPanel();
	public HTML chartInfo = new HTML();
	private ListBox sourceGroups = new ListBox();
	private ListBox sourcesList = new ListBox();
	private Image elevationImage = new Image();
	private JSONObject jsonSources = new JSONObject();


	//Button that plots the plot
        private Button plot = new Button("Save & Plot", new ClickListener() {
		public void onClick(Widget sender) {
		    chartInfo.setStyleName("flashinglabel");
		    chartInfo.setText("Loading...");
		    sources = "";
		    try{
			for (int i = 0; i < sourcesList.getItemCount(); ++i) {
			    if (sourcesList.isItemSelected(i)) {
				sources += sourcesList.getItemText(i) +","+sourcesList.getValue(i) + ":";
			    }
			}
		    } catch (Exception e){
			chartInfo.setStyleName("flashingreply");
			chartInfo.setHTML("Problem plotting");
		    }
		    chartInfo.setStyleName("");
		    chartInfo.setText("");
		    elevationImage.setUrl(getImageURL("large"));
		    
		}
	    });
	
	private void refreshList(){

	    chartInfo.setStyleName("blinkreply");
	    chartInfo.setHTML("Loading...");
	    String url = "cgi-bin/dbquery.pl?sources";
	    url = URL.encode(url);

	    //Create the new request and go with it...
	    RequestBuilder builder = new RequestBuilder(RequestBuilder.GET, url);  
	    try {
		Request request = builder.sendRequest(null, new RequestCallback() {
			public void onError(Request request, Throwable exception) {
			    chartInfo.setStyleName("flashingreply");
			    chartInfo.setHTML("Request Error");         
			}
			
			public void onResponseReceived(Request request, Response response) {
			    if (200 == response.getStatusCode()) {
				try{
				    //The backend should respond with a JSON string.
				    //If it doesn't, throw an error.
				    JSONValue jsonValue = JSONParser.parse(response.getText());
				    jsonSources = jsonValue.isObject();
				    if (jsonSources != null) {
					for(String group : jsonSources.keySet()){
					    if( group != "time"){
						sourceGroups.addItem(group);
					    }
					}
					sourceGroups.setSelectedIndex(3);
					loadList();	    
					chartInfo.setStyleName("");
					chartInfo.setHTML("");
				    } else {
					throw new JSONException(); 
				    }
				} catch (JSONException e) {
				    chartInfo.setStyleName("flashingreply");
				    chartInfo.setHTML("Couldn't parse JSON");
				}
			    } else {
				//This would be an http error.
				chartInfo.setStyleName("flashingreply");
				chartInfo.setHTML("Couldn't retrieve JSON (" + response.getStatusText() + ")");
			    }
			}       
		    });
	    } catch (RequestException e) {
		panel.displayError("Couldn't create request");         
	    }
        }
	
	private void loadList(){

	    try{
		JSONArray jsonArray = jsonSources.get(sourceGroups.getValue(sourceGroups.getSelectedIndex())).isArray();
		sourcesList.clear();
		for(int i = 0; i < jsonArray.size(); i++){
		    JSONObject sourceObject = jsonArray.get(i).isObject();
		    String coords = panel.cleanString(sourceObject.get("ra").toString()) 
			+ "," 
			+ panel.cleanString(sourceObject.get("dec").toString());
		    sourcesList.addItem(panel.cleanString(sourceObject.get("source").toString()),coords);
		}
	    } catch (Exception e){
		chartInfo.setStyleName("flashingreply");
		chartInfo.setHTML("error loading sources");
	    }  
	}



	public ChartPanel(){
	    HTML sourceHTML = new HTML("<center>Select a group from " +
				       "the first menu and then select " +
				       "a source from the second.<br/> "+
				       "<small>(hold &lt;ctrl&gt; to select "+
				       "multiple sources).</small></center>");
            FlowPanel buttonPanel = new FlowPanel();
	    buttonPanel.add(plot);
	    buttonPanel.setStyleName("reply");

	    elevationImage.setUrl(getImageURL("large"));

	    this.setPixelSize(600,400);
	    sourceGroups.setVisibleItemCount(1);
	    sourceGroups.setMultipleSelect(false);
	    sourcesList.setVisibleItemCount(20);
	    sourcesList.setMultipleSelect(true);
	    chartControl.setTitle("Control Panel");
            chartControl.setPixelSize(150,400);

	    refreshList();

	    sourceGroups.addChangeListener(new ChangeListener(){
 		    public void onChange(Widget sender){
			loadList();
 		    }
 		});

	    chartControl.add(sourceHTML);
            chartControl.add(sourceGroups);
	    chartControl.add(sourcesList);
            chartControl.add(buttonPanel);
            chartControl.add(chartInfo);
	    chartControl.setStyleName("PopupBox");
            
            this.add(elevationImage);
            this.add(chartControl);

	}
    }
}
