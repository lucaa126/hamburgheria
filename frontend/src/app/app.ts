import { Component, OnInit, OnDestroy, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterModule } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

// Interfacce per i dati
interface Product {
  id: number;
  nome: string;
  prezzo: number;
  categoria: string;
  immagine?: string;
}

interface Order {
  id: number;
  stato: string;
  data_creazione: string;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, CommonModule, RouterModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit, OnDestroy {
  private http = inject(HttpClient);
  
  // ⚠️ ATTENZIONE: Controlla che questo link sia quello attivo della porta 5000
  private apiUrl = 'https://silver-space-potato-r47pj5vpv74jh5r47-5000.app.github.dev';

  // --- STATO CON SIGNALS ---
  isMobileMenuOpen = signal(false);
  activeTab = signal<'ordini' | 'menu'>('ordini');
  activeCategory = signal('Tutte');
  
  orders = signal<Order[]>([]);
  menuItems = signal<Product[]>([]);
  showAddModal = signal(false);

  categories = ['Tutte', 'Panini', 'Fritti', 'Bevande', 'Menu'];
  
  // Oggetto per il nuovo prodotto
  newProduct = { nome: '', prezzo: 0, categoria: 'Panini', immagine: '' };
  
  private pollingInterval: any;

  ngOnInit() {
    this.loadOrders();
    this.loadProducts();

    // Polling: aggiorna gli ordini ogni 5 secondi
    this.pollingInterval = setInterval(() => {
      if (this.activeTab() === 'ordini') {
        this.loadOrders();
      }
    }, 5000);
  }

  ngOnDestroy() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }

  // --- UI HELPERS ---
  toggleMenu() { this.isMobileMenuOpen.update(val => !val); }
  closeMenu() { this.isMobileMenuOpen.set(false); }
  
  openAddProductModal() { this.showAddModal.set(true); }
  
  closeModal() { 
    this.showAddModal.set(false); 
    // Reset del form
    this.newProduct = { nome: '', prezzo: 0, categoria: 'Panini', immagine: '' };
  }

  // --- GESTIONE IMMAGINE (Base64) ---
  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e: any) => {
        // Salva la stringa base64 nell'oggetto newProduct
        this.newProduct.immagine = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  }

  // --- API CALLS ---

  // 1. Carica Prodotti
  loadProducts() {
    this.http.get<Product[]>(`${this.apiUrl}/products`).subscribe({
      next: (data) => this.menuItems.set(data),
      error: (err) => console.error('Errore caricamento prodotti:', err)
    });
  }

  // 2. Carica Ordini
  loadOrders() {
    this.http.get<Order[]>(`${this.apiUrl}/orders`).subscribe({
      next: (data) => this.orders.set(data),
      error: (err) => console.error('Errore caricamento ordini:', err)
    });
  }

  // 3. Cambia Stato Ordine
  changeOrderStatus(orderId: number, nuovoStato: string) {
    this.http.put(`${this.apiUrl}/orders/${orderId}`, { stato: nuovoStato }).subscribe({
      next: () => this.loadOrders(),
      error: (err) => console.error('Errore aggiornamento stato:', err)
    });
  }

  // 4. Elimina Prodotto
  deleteMenuItem(id: number) {
    if (!id) return;
    
    // Conferma semplice (opzionale, rimuovere se blocca)
    if(!confirm("Sei sicuro di voler eliminare questo prodotto?")) return;

    this.http.delete(`${this.apiUrl}/products/${id}`).subscribe({
      next: () => {
        console.log("Prodotto eliminato");
        this.loadProducts();
      },
      error: (err) => console.error('Errore eliminazione:', err)
    });
  }

  // 5. Salva Nuovo Prodotto
  saveProduct() {
    console.log("Invio dati:", this.newProduct); // Debug

    this.http.post(`${this.apiUrl}/products`, this.newProduct).subscribe({
      next: () => {
        console.log("Prodotto salvato!");
        this.loadProducts();
        this.closeModal();
      },
      error: (err) => {
        console.error('Errore salvataggio:', err);
        alert("Errore durante il salvataggio. Controlla la console.");
      }
    });
  }
}