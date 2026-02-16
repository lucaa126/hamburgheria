import { Component, OnInit, OnDestroy, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterModule } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

interface Product {
  id: number;
  nome: string;
  prezzo: number;
  categoria: string;
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
  
  // ⚠️ INCOLLA QUI IL TUO LINK CODESPACES (senza lo slash finale)
  private apiUrl = 'https://silver-space-potato-r47pj5vpv74jh5r47-5000.app.github.dev';

  // --- STATO CON SIGNALS ---
  isMobileMenuOpen = signal(false);
  activeTab = signal<'ordini' | 'menu'>('ordini');
  activeCategory = signal('Tutte');
  
  // Le liste dei dati ora sono Signals!
  orders = signal<Order[]>([]);
  menuItems = signal<Product[]>([]);
  showAddModal = signal(false);

  // Variabili standard per configurazioni statiche o form
  categories = ['Tutte', 'Panini', 'Fritti', 'Bevande', 'Menu'];
  newProduct = { nome: '', prezzo: 0, categoria: 'Panini' };
  
  private pollingInterval: any;

  ngOnInit() {
    this.loadOrders();
    this.loadProducts();

    // AUTO-REFRESH: Controlla nuovi ordini ogni 5 secondi in background
    this.pollingInterval = setInterval(() => {
      this.loadOrders();
    }, 5000);
  }

  ngOnDestroy() {
    // Pulisce il timer se cambiamo pagina
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }

  // --- LOGICA INTERFACCIA ---
  toggleMenu() { this.isMobileMenuOpen.update(val => !val); }
  closeMenu() { this.isMobileMenuOpen.set(false); }
  
  openAddProductModal() { this.showAddModal.set(true); }
  closeModal() { 
    this.showAddModal.set(false); 
    this.newProduct = { nome: '', prezzo: 0, categoria: 'Panini' };
  }

  // --- CHIAMATE AL BACKEND ---
  loadProducts() {
    this.http.get<Product[]>(`${this.apiUrl}/products`).subscribe({
      next: (data) => this.menuItems.set(data), // Aggiorna il signal
      error: (err) => console.error('Errore prodotti:', err)
    });
  }

  loadOrders() {
    this.http.get<Order[]>(`${this.apiUrl}/orders`).subscribe({
      next: (data) => this.orders.set(data), // Aggiorna il signal (riflette i dati in tempo reale)
      error: (err) => console.error('Errore ordini:', err)
    });
  }

  changeOrderStatus(orderId: number, nuovoStato: string) {
    this.http.put(`${this.apiUrl}/orders/${orderId}`, { stato: nuovoStato }).subscribe({
      next: () => {
        // Ricarica la lista per sicurezza, il signal aggiornerà l'interfaccia all'istante
        this.loadOrders();
      },
      error: (err) => console.error('Errore stato:', err)
    });
  }

  deleteMenuItem(id: number) {
    if(confirm('Sei sicuro di voler eliminare questo prodotto?')) {
      this.http.delete(`${this.apiUrl}/products/${id}`).subscribe({
        next: () => {
          this.loadProducts(); // Il signal farà sparire la riga all'istante
        },
        error: (err) => console.error('Errore eliminazione:', err)
      });
    }
  }

  saveProduct() {
    this.http.post(`${this.apiUrl}/products`, this.newProduct).subscribe({
      next: () => {
        this.loadProducts(); // Il signal farà comparire il nuovo panino all'istante
        this.closeModal();
      },
      error: (err) => console.error('Errore salvataggio:', err)
    });
  }
}