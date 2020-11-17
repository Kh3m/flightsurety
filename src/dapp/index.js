
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


let contract;

(async() => {

    // let result = null;

    contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        // Read user info

        let address = DOM.elid("yourAddress");
        address.innerHTML = "Your address :  "+contract.passengers[0]

        contract.credit((error, result) => {
            document.getElementById("creditAmount").innerText = "Available Credit For Withdrawal : "+result;
        });



        // Connect to server to get flight info

        const url = 'http://localhost:3000/api/fetchFlights'; 

        var xmlHttp = new XMLHttpRequest();
        xmlHttp.open( "GET", url, false ); // false for synchronous request
        xmlHttp.send( null );
        var jsonResponse= JSON.parse(xmlHttp.responseText);
        console.log(jsonResponse);

        let main = DOM.elid("flightTable");

        //create available flight table
        for(let a = 0; a < jsonResponse.length;a++){
            let newRow = document.createElement("tr");
            let flightnumber = document.createElement("td");
            let airline = document.createElement("td");
            let depart = document.createElement("td");
            // let status = document.createElement("td");
            let select = document.createElement("td");
            let timer = document.createElement("p");
            // let button = document.createElement("button");

            let airlines;

            contract.listRegistredAirline((error, result) => {
                // console.log(error, result);
                // console.log(jsonResponse[a].airline, result[1]);

                if(jsonResponse[a].airline == result[1]){
                    airlines = "American Airlines";
                }else if (jsonResponse[a].airline == result[2]){
                    airlines = "Delta Airlines";
                }else {
                    airlines = "United Airlines";
                }

                airline.appendChild(document.createTextNode(airlines)); 
            })
            
            flightnumber.appendChild(document.createTextNode(jsonResponse[a].flightNumber));

            depart.appendChild(document.createTextNode( new Date(jsonResponse[a].timestamp).toString().substring(0,28)));
            depart.classList.add("departures");
            // status.classList.add("showStatus");
            timer.classList.add("timeleft");
            depart.appendChild(timer);

            newRow.appendChild(flightnumber);
            newRow.appendChild(airline);
            // newRow.append(price);
            newRow.append(depart);
            // newRow.append(status);

            // button.appendChild(document.createTextNode("Purchase"));
            // button.classList.add("newButton");
            // button.setAttribute("id", a);

            // select.appendChild(button)
            // newRow.append(select);
            main.appendChild(newRow);
        }


        // Flight Number drop-down list
        let dropdown = DOM.elid('flight-number-list');
        let optionFlights;
        var airlineList = new Array();
        var flightList = new Array();

        // create a dropdown menu for flight number selection
        for(let a = 0; a < jsonResponse.length;a++){
            optionFlights = document.createElement('option');
            optionFlights.text = "";
            optionFlights.text = jsonResponse[a].flightNumber ;
            optionFlights.value = jsonResponse[a].flightNumber;
            dropdown.add(optionFlights);

            airlineList.push(jsonResponse[a].airline);
            flightList.push(jsonResponse[a].flightNumber);
            
        }

        // Departure date drop-down list
        let dropdownDeparture = DOM.elid('departure-date');
        let optionTime; 

        DOM.elid('flight-number-list').onchange = (function(){

            let flightInput = DOM.elid('flight-number-list').value;
            let indexFlightTimestamp = flightList.indexOf(flightInput);
            // console.log(flightInput);
            // console.log(indexFlightTimestamp);

            optionTime = document.createElement('option');
            optionTime.text = new Date(jsonResponse[indexFlightTimestamp].timestamp).toString().substring(0,28);
            optionTime.value = jsonResponse[indexFlightTimestamp].timestamp;
            dropdownDeparture.remove(0);
            dropdownDeparture.add(optionTime);
        });


        // Purchase button
        DOM.elid('purchase-insurance').addEventListener('click', () => {
            
            let flightNumber = DOM.elid('flight-number-list').value;
            let airline = airlineList[flightList.indexOf(flightNumber)];
            let timestamp = parseInt(DOM.elid('departure-date').value);
            let insuranceAmount = DOM.elid('insurance-amount').value;

            // console.log(flightNumber, airline, timestamp, insuranceAmount);
            
            // Write transaction 
            contract.buyTicket(airline, flightNumber, timestamp, insuranceAmount, contract.passengers[0],(error, result) => {
                // console.log(error);
                console.log(result);
                purchaseFlight(error,result);
            });
        });


        // Withdrawal
        DOM.elid('withdraw-credit').addEventListener('click', () => {
            let withdrawalAmount = DOM.elid('withdraw-amount').value;
            // Write transaction
            contract.redeemCredit(withdrawalAmount, contract.passengers[0], (error, result) => {
                console.log(result);
            });

            let address = DOM.elid("yourAddress");
            address.innerHTML = "Your address :  "+contract.passengers[0]

            setTimeout(() =>{
                contract.credit((error, result) => {
                    document.getElementById("creditAmount").innerText = "Available Credit For Withdrawal : "+result;
                });
            },1000);


        })
    
    });
    
})();

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

function purchaseFlight(error,flight) {
    if (error == null){
        let main = DOM.elid("yourFlights");
        let newRow = document.createElement("tr");
        let flightnumber = document.createElement("td");
        let airline = document.createElement("td");
        let insureAmount = document.createElement("td");
        let insure = document.createElement("button");
        let buttonT = document.createElement("td");
        let depart = document.createElement("td");
        let status = document.createElement("td");
        let td = document.createElement("td");


        // pass in flight number
        flightnumber.appendChild(document.createTextNode(flight.flight));
        newRow.appendChild(flightnumber);

        // pass in airline
        let airlines;
        (async()=>{
            contract.listRegistredAirline((error, result) => {
                // console.log(error, result);
                // console.log(jsonResponse[a].airline, result[1]);

                if(flight.airline == result[1]){
                    airlines = "American Airlines";
                }else if (flight.airline == result[2]){
                    airlines = "Delta Airlines";
                }else {
                    airlines = "United Airlines";
                }

                airline.appendChild(document.createTextNode(airlines));

            })
        })()

        // pass in departure time
        var departureTimeFormatted = new Date(parseInt(flight.timestamp)).toString().substring(0,28)
        depart.appendChild(document.createTextNode(departureTimeFormatted));

        // pass in insurance amount
        insureAmount.appendChild(document.createTextNode(flight.price/1000000000000000000));
        newRow.appendChild(insureAmount);

        // create "Fetch Flight button"
        insure.appendChild(document.createTextNode("Fetch Flight Status"));
        insure.classList.add("newInsure");
        insure.onclick = function() {
            let div = document.createElement("div");
            div.classList.add("loader");
            insure.appendChild(div);
            contract.fetchFlightStatus(flight,(error, result) => {
                if (error == null){
                    // console.log(result);
                    insure.disabled = true;
                }else{
                    alert(error);
                }
            });

            this.removeChild(div);

            // pass in status
            // status.classList.add("showStatus");
            let statusNow = "Loading...";
            status.appendChild(document.createTextNode(statusNow));


            setTimeout(() => {    
                contract.getFlightStatusCode(flight, (error, result) => {
                    console.log(result);
                    if (error == null){
                        if(result == 0){
                            statusNow = "Need to fetch flight status";
                            // statusNow.style.color = "yellow";
                        }else if(result == 50){
                            statusNow = "Late Other";
                            // statusNow.style.color = "red";
                        }else if (result == 40) {
                            statusNow = "Late Technical"
                            // statusNow.style.color = "red";
                        }else if (result == 30) {
                            statusNow = "Late Weather"
                            // statusNow.style.color = "red";
                        }else if (result == 20) {
                            statusNow= "Late Airline -- Payout 1.5x "
                            // statusNow.style.color = "red";
                        }else if (result == 10) {
                            statusNow = "On Time"
                            // statusNow.style.color = "#00ff00";
                        }else{
                            statusNow = "Unknown"
                            // statusNow.style.color = "yellow";
                        }
                    }else{
                        alert(error);
                    }
                    status.removeChild(status.lastChild);
                    status.appendChild(document.createTextNode(statusNow));
                });
                

                let address = DOM.elid("yourAddress");
                address.innerHTML = "Your address :  "+contract.passengers[0]

                contract.credit((error, result) => {
                    document.getElementById("creditAmount").innerText = "Available Credit For Withdrawal : "+result;
                });

                
            }, 5000);

            

        }

        newRow.appendChild(airline);
        newRow.append(depart);
        newRow.append(insureAmount);
        newRow.append(status);
        buttonT.append(insure);
        newRow.append(buttonT);
        main.appendChild(newRow);
    }else{
        alert(error);
    }

}







